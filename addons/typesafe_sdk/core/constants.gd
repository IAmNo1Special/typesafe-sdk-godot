class_name TypeSafeConstants
extends RefCounted

# Mirrors typesafe_sdk.constants from the Python SDK.
# https://docs.typesafe.ai/sdk/python/api/constants

const API_KEY_ENV: String = "TYPESAFE_API_KEY"
const BASE_URL_ENV: String = "TYPESAFE_BASE_URL"
const DEFAULT_MODEL_ENV: String = "TYPESAFE_DEFAULT_MODEL"
const LOG_LEVEL_ENV: String = "TYPESAFE_LOG_LEVEL"

const DEFAULT_BASE_URL: String = "https://api.typesafe.ai"
const DEFAULT_MODEL: String = "jev-latest"
const DEFAULT_TIMEOUT: float = 10.0

const SDK_NAME: String = "typesafe-sdk-godot"
const SDK_VERSION: String = "0.1.0"
