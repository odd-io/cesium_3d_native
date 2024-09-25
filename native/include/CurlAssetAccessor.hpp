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
            auto request = std::make_shared<CurlAssetRequest>(verb, url, CesiumAsync::HttpHeaders(headers.begin(), headers.end()));
            
            CURL* curl = curl_easy_init();
            if (!curl) {
                throw std::runtime_error("Failed to initialize CURL");
            }
            char *capath = NULL;
            curl_easy_getinfo(curl, CURLINFO_CAPATH, capath);
            curl_easy_setopt(curl, CURLOPT_FRESH_CONNECT, 1L);
            // curl_easy_setopt(curl, CURLOPT_VERBOSE, 1L);
            curl_easy_setopt(curl, CURLOPT_SSL_SESSIONID_CACHE, 0L);
            curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 1L);
            curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 2L);
            curl_easy_setopt(curl, CURLOPT_CAPATH, "/etc/security/cacerts/");
            curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
            curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, verb.c_str());
            curl_easy_setopt(curl, CURLOPT_ACCEPT_ENCODING, "");

            struct curl_slist* chunk = nullptr;
            for (const auto& header : headers) {
                std::string headerStr = header.first + ": " + header.second;
                chunk = curl_slist_append(chunk, headerStr.c_str());
            }

            // Add Accept-Encoding header for compressed responses
            chunk = curl_slist_append(chunk, "Accept-Encoding: gzip, deflate");

            // if (!_authToken.empty()) {
            //     std::string authHeader = "Authorization: Bearer " + _authToken;
            //     chunk = curl_slist_append(chunk, authHeader.c_str());
            // }

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
            
            CURLcode res = curl_easy_perform(curl);

            if (res != CURLE_OK) {
                spdlog::default_logger()->error("CURL Failed!  Error: {}", curl_easy_strerror(res));
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