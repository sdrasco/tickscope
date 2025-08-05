#include "polygon_iv.h"

#include <curl/curl.h>
#include <string>
#include <utility>

namespace {
size_t WriteCallback(void *contents, size_t size, size_t nmemb, void *userp) {
    std::string *s = static_cast<std::string *>(userp);
    s->append(static_cast<char *>(contents), size * nmemb);
    return size * nmemb;
}
} // namespace

PolygonIVFetcher::PolygonIVFetcher(std::string apiKey, std::chrono::seconds cacheDuration)
    : apiKey_(std::move(apiKey)), cacheDuration_(cacheDuration) {}

bool PolygonIVFetcher::isStale(const CacheEntry &entry) const {
    return (std::chrono::steady_clock::now() - entry.timestamp) > cacheDuration_;
}

std::optional<double> PolygonIVFetcher::fetchFromPolygon(const std::string &optionSymbol) {
    CURL *curl = curl_easy_init();
    if (!curl) return std::nullopt;

    std::string url = "https://api.polygon.io/v2/snapshot/options/" + optionSymbol + "?apiKey=" + apiKey_;
    std::string buffer;

    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &buffer);

    CURLcode res = curl_easy_perform(curl);
    curl_easy_cleanup(curl);

    if(res != CURLE_OK) {
        return std::nullopt;
    }

    auto pos = buffer.find("\"implied_volatility\":");
    if(pos == std::string::npos) return std::nullopt;
    pos += std::string("\"implied_volatility\":").size();
    size_t end = buffer.find_first_of(",}", pos);
    if(end == std::string::npos) return std::nullopt;

    double iv = 0.0;
    try {
        iv = std::stod(buffer.substr(pos, end - pos));
    } catch(const std::exception &) {
        return std::nullopt;
    }
    return iv;
}

std::optional<double> PolygonIVFetcher::getIV(const std::string &optionSymbol) {
    auto now = std::chrono::steady_clock::now();
    auto it = cache_.find(optionSymbol);
    if (it != cache_.end() && !isStale(it->second)) {
        return it->second.iv;
    }

    auto iv = fetchFromPolygon(optionSymbol);
    if (iv) {
        cache_[optionSymbol] = { *iv, now };
    }
    return iv;
}

void PolygonIVFetcher::notifyMajorMove(const std::string &underlyingSymbol) {
    for (auto it = cache_.begin(); it != cache_.end(); ) {
        if (it->first.find(underlyingSymbol) != std::string::npos) {
            it = cache_.erase(it);
        } else {
            ++it;
        }
    }
}

