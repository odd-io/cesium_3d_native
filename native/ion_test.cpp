#include <CesiumAsync/AsyncSystem.h>
#include <CesiumAsync/IAssetAccessor.h>
#include <CesiumAsync/IAssetResponse.h>
#include <CesiumIonClient/Connection.h>
#include <CesiumUtility/Uri.h>
#include <iostream>
#include <memory>
#include <vector>
#include <curl/curl.h>

class SimpleTaskProcessor : public CesiumAsync::ITaskProcessor {
public:
    virtual void startTask(std::function<void()> f) override {
        f();
    }
};

class SimpleAssetResponse : public CesiumAsync::IAssetResponse {
public:
    SimpleAssetResponse(
        uint16_t statusCode,
        const std::string& contentType,
        const CesiumAsync::HttpHeaders& headers,
        std::vector<std::byte>&& data)
        : _statusCode(statusCode), _contentType(contentType), _headers(headers), _data(std::move(data)) {}

    virtual uint16_t statusCode() const noexcept override { return _statusCode; }
    virtual std::string contentType() const noexcept override { return _contentType; }
    virtual const CesiumAsync::HttpHeaders& headers() const noexcept override { return _headers; }
    virtual gsl::span<const std::byte> data() const noexcept override { return _data; }

private:
    uint16_t _statusCode;
    std::string _contentType;
    CesiumAsync::HttpHeaders _headers;
    std::vector<std::byte> _data;
};

class SimpleAssetRequest : public CesiumAsync::IAssetRequest {
public:
    SimpleAssetRequest(
        const std::string& method,
        const std::string& url,
        const CesiumAsync::HttpHeaders& headers)
        : _method(method), _url(url), _headers(headers), _pResponse(nullptr) {}

    virtual const std::string& method() const override { return _method; }
    virtual const std::string& url() const override { return _url; }
    virtual const CesiumAsync::HttpHeaders& headers() const override { return _headers; }
    virtual const CesiumAsync::IAssetResponse* response() const override { return _pResponse.get(); }

    void setResponse(std::unique_ptr<SimpleAssetResponse> pResponse) {
        _pResponse = std::move(pResponse);
    }

private:
    std::string _method;
    std::string _url;
    CesiumAsync::HttpHeaders _headers;
    std::unique_ptr<SimpleAssetResponse> _pResponse;
};

class SimpleAssetAccessor : public CesiumAsync::IAssetAccessor {
public:
    SimpleAssetAccessor() {
    if (curl_global_init(CURL_GLOBAL_DEFAULT) != CURLE_OK) {
        throw std::runtime_error("Failed to initialize CURL");
    }
    std::cout << "CURL initialized" << std::endl;
    
    // Print CURL version information
    curl_version_info_data* version_info = curl_version_info(CURLVERSION_NOW);
    std::cout << "CURL version: " << version_info->version << std::endl;
    std::cout << "SSL version: " << version_info->ssl_version << std::endl;
}

    ~SimpleAssetAccessor() {
        curl_global_cleanup();
        std::cout << "CURL cleaned up" << std::endl;
    }

    virtual CesiumAsync::Future<std::shared_ptr<CesiumAsync::IAssetRequest>> get(
        const CesiumAsync::AsyncSystem& asyncSystem,
        const std::string& url,
        const std::vector<CesiumAsync::IAssetAccessor::THeader>& headers) override {
        std::cout << "GET request to: " << url << std::endl;
        return request(asyncSystem, "GET", url, headers, {});
    }

    virtual CesiumAsync::Future<std::shared_ptr<CesiumAsync::IAssetRequest>> request(
    const CesiumAsync::AsyncSystem& asyncSystem,
    const std::string& verb,
    const std::string& url,
    const std::vector<CesiumAsync::IAssetAccessor::THeader>& headers,
    const gsl::span<const std::byte>& contentPayload) override {
    
    std::cout << "Performing " << verb << " request to: " << url << std::endl;

    auto pRequest = std::make_shared<SimpleAssetRequest>(verb, url, CesiumAsync::HttpHeaders(headers.begin(), headers.end()));

    return asyncSystem.createFuture<std::shared_ptr<CesiumAsync::IAssetRequest>>(
        [this, pRequest, verb, url, headers, contentPayload](const auto& promise) {
            CURL* curl = curl_easy_init();
            if (!curl) {
                promise.reject(std::runtime_error("Failed to initialize CURL"));
                return;
            }

            std::cout << "CURL initialized for request" << std::endl;

            curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
            curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, verb.c_str());
            
            // Enable verbose output for debugging
            curl_easy_setopt(curl, CURLOPT_VERBOSE, 1L);
            
            // Set SSL verification options
            curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 1L);
            curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 2L);

            struct curl_slist* chunk = NULL;
            for (const auto& header : headers) {
                std::string headerStr = header.first + ": " + header.second;
                chunk = curl_slist_append(chunk, headerStr.c_str());
            }
            curl_easy_setopt(curl, CURLOPT_HTTPHEADER, chunk);

            if (!contentPayload.empty()) {
                curl_easy_setopt(curl, CURLOPT_POSTFIELDS, contentPayload.data());
                curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, contentPayload.size());
            }

            std::string responseData;
            curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, 
                [](void* contents, size_t size, size_t nmemb, void* userp) -> size_t {
                    size_t realsize = size * nmemb;
                    static_cast<std::string*>(userp)->append(static_cast<char*>(contents), realsize);
                    return realsize;
                });
            curl_easy_setopt(curl, CURLOPT_WRITEDATA, &responseData);

            std::cout << "Performing CURL request..." << std::endl;
            CURLcode res = curl_easy_perform(curl);
            std::cout << "Easy perform finish..." << std::endl;
            if (res != CURLE_OK) {
                std::string errorMsg = "CURL error: " + std::string(curl_easy_strerror(res));
                std::cerr << errorMsg << std::endl;
                promise.reject(std::runtime_error(errorMsg));
            } else {
                long response_code;
                curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &response_code);

                char* content_type;
                curl_easy_getinfo(curl, CURLINFO_CONTENT_TYPE, &content_type);

                std::cout << "Response received. Status code: " << response_code << std::endl;
                std::cout << "Content-Type: " << (content_type ? content_type : "unknown") << std::endl;
                std::cout << "Response body length: " << responseData.length() << std::endl;
                std::cout << "First 100 characters of response body: " << responseData.substr(0, 100) << std::endl;

                try {
                    std::cout << "Creating SimpleAssetResponse..." << std::endl;
                    auto pResponse = std::make_unique<SimpleAssetResponse>(
                        static_cast<uint16_t>(response_code),
                        content_type ? content_type : "",
                        CesiumAsync::HttpHeaders(),
                        std::vector<std::byte>(
                            reinterpret_cast<const std::byte*>(responseData.data()),
                            reinterpret_cast<const std::byte*>(responseData.data() + responseData.size())
                        ));
                    std::cout << "SimpleAssetResponse created successfully" << std::endl;

                    std::cout << "Setting response on SimpleAssetRequest..." << std::endl;
                    pRequest->setResponse(std::move(pResponse));
                    std::cout << "Response set successfully" << std::endl;

                    std::cout << "Resolving promise..." << std::endl;
                    promise.resolve(pRequest);
                    std::cout << "Promise resolved" << std::endl;
                } catch (const std::exception& e) {
                    std::cerr << "Exception while processing response: " << e.what() << std::endl;
                    promise.reject(std::runtime_error(std::string("Exception while processing response: ") + e.what()));
                } catch (...) {
                    std::cerr << "Unknown exception while processing response" << std::endl;
                    promise.reject(std::runtime_error("Unknown exception while processing response"));
                }
            }

            curl_slist_free_all(chunk);
            curl_easy_cleanup(curl);
            std::cout << "CURL request completed and cleaned up" << std::endl;
        });
}

    virtual void tick() noexcept override {}
};

// Helper function to wait for a future to complete
template<typename T>
T waitForFuture(CesiumAsync::AsyncSystem& asyncSystem, CesiumAsync::Future<T>&& future) {
    while (!future.isReady()) {
        asyncSystem.dispatchMainThreadTasks();
    }
    return future.wait();
}

int main(int argc, char* argv[]) {
    if (argc != 2) {
        std::cerr << "Usage: " << argv[0] << " <access_token>" << std::endl;
        return 1;
    }

    std::string accessToken = argv[1];
    std::cout << "Access token: " << accessToken << std::endl;

    try {
        CesiumAsync::AsyncSystem asyncSystem(std::make_shared<SimpleTaskProcessor>());
        std::cout << "AsyncSystem created" << std::endl;

        auto pAssetAccessor = std::make_shared<SimpleAssetAccessor>();
        std::cout << "SimpleAssetAccessor created" << std::endl;

        CesiumIonClient::ApplicationData appData;
        std::cout << "Creating Connection..." << std::endl;
        CesiumIonClient::Connection connection(
            asyncSystem,
            pAssetAccessor,
            accessToken,
            appData);
        std::cout << "Connection created" << std::endl;

        std::cout << "Requesting assets..." << std::endl;
        CesiumAsync::Future<CesiumIonClient::Response<CesiumIonClient::Assets>> futureAssets = connection.assets();
        std::cout << "Future created, waiting for result..." << std::endl;
        
        try {
            CesiumIonClient::Response<CesiumIonClient::Assets> assets = waitForFuture(asyncSystem, std::move(futureAssets));
            std::cout << "Future resolved" << std::endl;

            if (assets.value) {
                std::cout << "Assets associated with this token:" << std::endl;
                for (const auto& asset : assets.value->items) {
                    std::cout << "ID: " << asset.id << ", Name: " << asset.name << ", Type: " << asset.type << std::endl;
                }
            } else {
                std::cout << "Failed to get assets. Error code: " << assets.errorCode << ", Message: " << assets.errorMessage << std::endl;
            }
        } catch (const std::exception& e) {
            std::cerr << "Exception while waiting for future: " << e.what() << std::endl;
        } catch (...) {
            std::cerr << "Unknown exception while waiting for future" << std::endl;
        }
    } catch (const std::exception& e) {
        std::cerr << "An exception occurred: " << e.what() << std::endl;
        return 1;
    } catch (...) {
        std::cerr << "An unknown exception occurred" << std::endl;
        return 1;
    }

    return 0;
}