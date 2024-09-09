// This file was generated by generate-classes.
// DO NOT EDIT THIS FILE!
#pragma once

#include <Cesium3DTiles/PropertyStatistics.h>
#include <Cesium3DTilesReader/Library.h>
#include <CesiumJsonReader/JsonReader.h>
#include <CesiumJsonReader/JsonReaderOptions.h>

#include <gsl/span>
#include <rapidjson/fwd.h>

#include <vector>

namespace Cesium3DTiles {
struct PropertyStatistics;
}

namespace Cesium3DTilesReader {

/**
 * @brief Reads {@link PropertyStatistics} instances from JSON.
 */
class CESIUM3DTILESREADER_API PropertyStatisticsReader {
public:
  /**
   * @brief Constructs a new instance.
   */
  PropertyStatisticsReader();

  /**
   * @brief Gets the options controlling how the JSON is read.
   */
  CesiumJsonReader::JsonReaderOptions& getOptions();

  /**
   * @brief Gets the options controlling how the JSON is read.
   */
  const CesiumJsonReader::JsonReaderOptions& getOptions() const;

  /**
   * @brief Reads an instance of PropertyStatistics from a byte buffer.
   *
   * @param data The buffer from which to read the instance.
   * @return The result of reading the instance.
   */
  CesiumJsonReader::ReadJsonResult<Cesium3DTiles::PropertyStatistics>
  readFromJson(const gsl::span<const std::byte>& data) const;

  /**
   * @brief Reads an instance of PropertyStatistics from a rapidJson::Value.
   *
   * @param data The buffer from which to read the instance.
   * @return The result of reading the instance.
   */
  CesiumJsonReader::ReadJsonResult<Cesium3DTiles::PropertyStatistics>
  readFromJson(const rapidjson::Value& value) const;

  /**
   * @brief Reads an array of instances of PropertyStatistics from a
   * rapidJson::Value.
   *
   * @param data The buffer from which to read the array of instances.
   * @return The result of reading the array of instances.
   */
  CesiumJsonReader::ReadJsonResult<
      std::vector<Cesium3DTiles::PropertyStatistics>>
  readArrayFromJson(const rapidjson::Value& value) const;

private:
  CesiumJsonReader::JsonReaderOptions _options;
};

} // namespace Cesium3DTilesReader