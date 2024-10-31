#include <Cesium3DTilesSelection/Tileset.h>
#include <Cesium3DTilesSelection/TilesetExternals.h>
#include <CesiumAsync/IAssetAccessor.h>
#include <CesiumAsync/IAssetResponse.h>
#include <CesiumAsync/AsyncSystem.h>
#include <memory>
#include <vector>
#include <curl/curl.h>
#include <iostream>
#include <sstream>
#include <zlib.h>
#include <chrono>

using namespace Cesium3DTilesSelection;

class CurlAssetResponse : public CesiumAsync::IAssetResponse {
public:
    CurlAssetResponse(long statusCode, const std::string& contentType, const std::vector<uint8_t>& data)
        : _statusCode(statusCode), _contentType(contentType), _data(data) {}

    virtual uint16_t statusCode() const override { return static_cast<uint16_t>(_statusCode); }
    virtual const CesiumAsync::HttpHeaders& headers() const override { return _headers; }
    virtual gsl::span<const std::byte> data() const override {
        return gsl::span<const std::byte>(reinterpret_cast<const std::byte*>(_data.data()), _data.size());
    }
    virtual std::string contentType() const override {
        return _contentType;
    }


private:
    long _statusCode;
    std::string _contentType;
    std::vector<uint8_t> _data;
    CesiumAsync::HttpHeaders _headers;
};

class CurlAssetRequest : public CesiumAsync::IAssetRequest {
public:
    CurlAssetRequest(const std::string& method, const std::string& url, const CesiumAsync::HttpHeaders& headers)
        : _method(method), _url(url), _headers(headers) {}

    virtual const std::string& method() const override { return _method; }
    virtual const std::string& url() const override { return _url; }
    virtual const CesiumAsync::HttpHeaders& headers() const override { return _headers; }
    virtual const CesiumAsync::IAssetResponse* response() const override { return _response.get(); }

    void setResponse(std::unique_ptr<CurlAssetResponse> response) {
        _response = std::move(response);
    }

private:
    std::string _method;
    std::string _url;
    CesiumAsync::HttpHeaders _headers;
    std::unique_ptr<CurlAssetResponse> _response;
};

class CurlAssetAccessor : public CesiumAsync::IAssetAccessor {
public:
    CurlAssetAccessor(const std::string& authToken = "") : _authToken(authToken) {
        curl_global_init(CURL_GLOBAL_DEFAULT);
    }

    ~CurlAssetAccessor() {
        curl_global_cleanup();
    }

    void setAuthToken(const std::string& authToken) {
        _authToken = authToken;
    }

    CesiumAsync::Future<std::shared_ptr<CesiumAsync::IAssetRequest>> get(
        const CesiumAsync::AsyncSystem& asyncSystem,
        const std::string& url,
        const std::vector<CesiumAsync::IAssetAccessor::THeader>& headers) override {
        return request(asyncSystem, "GET", url, headers);
    }

    CesiumAsync::Future<std::shared_ptr<CesiumAsync::IAssetRequest>> request(
        const CesiumAsync::AsyncSystem& asyncSystem,
        const std::string& verb,
        const std::string& url,
        const std::vector<THeader>& headers,
        const gsl::span<const std::byte>& contentPayload = {}) override {
       
        return asyncSystem.runInWorkerThread([this, verb, url, headers, contentPayload]() {
            auto startTime = std::chrono::high_resolution_clock::now();
            spdlog::info("Starting {} request to: {}", verb, url);

            auto request = std::make_shared<CurlAssetRequest>(verb, url, CesiumAsync::HttpHeaders(headers.begin(), headers.end()));
            
            CURL* curl = curl_easy_init();
            if (!curl) {
                throw std::runtime_error("Failed to initialize CURL");
            }
            
            curl_easy_setopt(curl, CURLOPT_FRESH_CONNECT, 1L);
            // curl_easy_setopt(curl, CURLOPT_VERBOSE, 1L);
            curl_easy_setopt(curl, CURLOPT_SSL_SESSIONID_CACHE, 0L);
            curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 1L);
            curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 2L);
            #ifdef __ANDROID_API__
            char *capath = NULL;
            curl_easy_getinfo(curl, CURLINFO_CAPATH, capath);
            curl_easy_setopt(curl, CURLOPT_CAPATH, "/etc/security/cacerts/");
            #endif
            curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
            curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, verb.c_str());
            curl_easy_setopt(curl, CURLOPT_ACCEPT_ENCODING, "");

            struct curl_slist* chunk = nullptr;
            for (const auto& header : headers) {
                std::string headerStr = header.first + ": " + header.second;
                chunk = curl_slist_append(chunk, headerStr.c_str());
            }

            chunk = curl_slist_append(chunk, "Accept-Encoding: gzip, deflate");

            curl_easy_setopt(curl, CURLOPT_HTTPHEADER, chunk);

            if (!contentPayload.empty()) {
                curl_easy_setopt(curl, CURLOPT_POSTFIELDS, contentPayload.data());
                curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, contentPayload.size());
            }

            std::vector<uint8_t> responseData;
            char errbuf[CURL_ERROR_SIZE];
            curl_easy_setopt(curl, CURLOPT_ERRORBUFFER, errbuf);
            curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
            curl_easy_setopt(curl, CURLOPT_WRITEDATA, &responseData);
            
            // Get timing information
            double totalTime, nameLookupTime, connectTime, appConnectTime, preTransferTime, startTransferTime;
            
            CURLcode res = curl_easy_perform(curl);

            auto endTime = std::chrono::high_resolution_clock::now();
            auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(endTime - startTime);

            // Get detailed timing information from CURL
            curl_easy_getinfo(curl, CURLINFO_TOTAL_TIME, &totalTime);
            curl_easy_getinfo(curl, CURLINFO_NAMELOOKUP_TIME, &nameLookupTime);
            curl_easy_getinfo(curl, CURLINFO_CONNECT_TIME, &connectTime);
            curl_easy_getinfo(curl, CURLINFO_APPCONNECT_TIME, &appConnectTime);
            curl_easy_getinfo(curl, CURLINFO_PRETRANSFER_TIME, &preTransferTime);
            curl_easy_getinfo(curl, CURLINFO_STARTTRANSFER_TIME, &startTransferTime);

            if (res != CURLE_OK) {
                spdlog::default_logger()->error("CURL Failed! Error: {}", curl_easy_strerror(res));
                spdlog::default_logger()->error("Response body: {}", std::string(responseData.begin(), responseData.end()));
                spdlog::default_logger()->error("{}", errbuf);

                curl_easy_cleanup(curl);
                curl_slist_free_all(chunk);
                throw std::runtime_error(curl_easy_strerror(res));
            }

            long statusCode;
            curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &statusCode);

            char* contentType;
            curl_easy_getinfo(curl, CURLINFO_CONTENT_TYPE, &contentType);

            // Log timing information
            // spdlog::default_logger()->info("Request completed: {} {}", verb, url);
            // spdlog::default_logger()->info("Status: {}", statusCode);
            // spdlog::default_logger()->info("Total time: {:.2f} ms", duration.count());
            // spdlog::default_logger()->info("CURL Timing breakdown:");
            // spdlog::default_logger()->info("  DNS lookup:    {:.2f} ms", nameLookupTime * 1000);
            // spdlog::default_logger()->info("  TCP connect:   {:.2f} ms", (connectTime - nameLookupTime) * 1000);
            // spdlog::default_logger()->info("  SSL handshake: {:.2f} ms", (appConnectTime - connectTime) * 1000);
            // spdlog::default_logger()->info("  Pre-transfer:  {:.2f} ms", (preTransferTime - appConnectTime) * 1000);
            // spdlog::default_logger()->info("  Transfer:      {:.2f} ms", (totalTime - startTransferTime) * 1000);
            // spdlog::default_logger()->info("Response size: {} bytes", responseData.size());

            auto response = std::make_unique<CurlAssetResponse>(statusCode, contentType ? contentType : "", responseData);
            request->setResponse(std::move(response));

            curl_easy_cleanup(curl);
            curl_slist_free_all(chunk);

            return (std::shared_ptr<CesiumAsync::IAssetRequest>)request;
        });
    }


    void tick() noexcept override {}

private:
    std::string _authToken;

    static size_t WriteCallback(void* contents, size_t size, size_t nmemb, void* userp) {
        size_t realsize = size * nmemb;
        auto& buffer = *static_cast<std::vector<uint8_t>*>(userp);
        size_t currentSize = buffer.size();
        buffer.resize(currentSize + realsize);
        std::memcpy(buffer.data() + currentSize, contents, realsize);
        return realsize;
    }
};