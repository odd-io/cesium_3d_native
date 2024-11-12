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
    CurlAssetResponse(long statusCode, const std::string& contentType, const std::vector<uint8_t>& data, const CesiumAsync::HttpHeaders& headers)
        : _statusCode(statusCode), _contentType(contentType), _data(data), _headers(headers) {
        // spdlog::debug("CurlAssetResponse headers:");
        // for (const auto& [key, value] : _headers) {
        //     spdlog::debug("  {}: {}", key, value);
        // }
    }

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
            // spdlog::debug("Starting {} request to: {}", verb, url);
            
            auto request = std::make_shared<CurlAssetRequest>(verb, url, CesiumAsync::HttpHeaders(headers.begin(), headers.end()));
            
            CURL* curl = curl_easy_init();
            if (!curl) {
                throw std::runtime_error("Failed to initialize CURL");
            }

            // Set up response headers collection before the request
            CesiumAsync::HttpHeaders responseHeaders;
            curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION, HeaderCallback);
            curl_easy_setopt(curl, CURLOPT_HEADERDATA, &responseHeaders);
            
            // Basic CURL setup
            curl_easy_setopt(curl, CURLOPT_FRESH_CONNECT, 0L);
            curl_easy_setopt(curl, CURLOPT_SSL_SESSIONID_CACHE, 1L);
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

            // Prepare request headers
            struct curl_slist* chunk = nullptr;
            
            // Add cache control headers if not present in the original request
            bool hasCacheControl = false;
            for (const auto& header : headers) {
                std::string headerStr = header.first + ": " + header.second;
                chunk = curl_slist_append(chunk, headerStr.c_str());
                spdlog::debug("Request header: {}", headerStr);
                
                if (header.first == "Cache-Control") {
                    hasCacheControl = true;
                }
            }

            if (!hasCacheControl) {
                // default is 1 hour
                const char* cacheControl = "Cache-Control: max-age=3600";
                chunk = curl_slist_append(chunk, cacheControl);
                spdlog::debug("Added default {}", cacheControl);
            }

            chunk = curl_slist_append(chunk, "Accept-Encoding: gzip, deflate");
            curl_easy_setopt(curl, CURLOPT_HTTPHEADER, chunk);

            // Set up response data collection
            std::vector<uint8_t> responseData;
            curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
            curl_easy_setopt(curl, CURLOPT_WRITEDATA, &responseData);

            // Execute request
            CURLcode res = curl_easy_perform(curl);
            
            if (res != CURLE_OK) {
                spdlog::error("CURL request failed: {}", curl_easy_strerror(res));
                curl_easy_cleanup(curl);
                curl_slist_free_all(chunk);
                throw std::runtime_error(curl_easy_strerror(res));
            }

            // Get response info
            long statusCode;
            curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &statusCode);

            char* contentType;
            curl_easy_getinfo(curl, CURLINFO_CONTENT_TYPE, &contentType);

            // Add Expires header if not present in response
            if (responseHeaders.find("Expires") == responseHeaders.end()) {
                std::time_t now = std::time(nullptr);
                // default is 1 hour like in the generated cache-control header
                std::time_t expires = now + 3600;
                char expiresStr[100];
                std::strftime(expiresStr, sizeof(expiresStr), "%a, %d %b %Y %H:%M:%S GMT", std::gmtime(&expires));
                responseHeaders["Expires"] = expiresStr;
                // spdlog::debug("Added Expires header: {}", expiresStr);
            }

            auto response = std::make_unique<CurlAssetResponse>(
                statusCode,
                contentType ? contentType : "",
                responseData,
                responseHeaders
            );
            request->setResponse(std::move(response));

            curl_easy_cleanup(curl);
            curl_slist_free_all(chunk);

            // spdlog::debug("Request completed: {} {} (status: {})", verb, url, statusCode);
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

    static size_t HeaderCallback(char* buffer, size_t size, size_t nitems, void* userdata) {
        size_t totalSize = size * nitems;
        std::string header(buffer, totalSize);
        auto* headers = static_cast<CesiumAsync::HttpHeaders*>(userdata);
        
        // Find the colon separator
        size_t colonPos = header.find(':');
        if (colonPos != std::string::npos) {
            std::string key = header.substr(0, colonPos);
            std::string value = header.substr(colonPos + 1);
            
            // Trim whitespace
            key.erase(0, key.find_first_not_of(" \t\r\n"));
            key.erase(key.find_last_not_of(" \t\r\n") + 1);
            value.erase(0, value.find_first_not_of(" \t\r\n"));
            value.erase(value.find_last_not_of(" \t\r\n") + 1);
            
            if (!key.empty()) {
                (*headers)[key] = value;
            }
        }
        
        return totalSize;
    }
};