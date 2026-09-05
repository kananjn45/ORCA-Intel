"""
ORCA — Voice Pipeline Custom Exceptions.

Structured exceptions that convey errors without leaking
API keys, authorization headers, or internal stack traces.
"""

from __future__ import annotations


class BhashiniError(Exception):
    """Base exception for all Bhashini service errors."""

    def __init__(self, message: str = "Bhashini service error") -> None:
        self.message = message
        super().__init__(self.message)


class BhashiniConfigurationError(BhashiniError):
    """Raised when Bhashini credentials or configuration are missing/invalid."""

    def __init__(self, message: str = "Bhashini API credentials are not configured") -> None:
        super().__init__(message)


class BhashiniAPIError(BhashiniError):
    """Raised when the Bhashini API returns an HTTP error."""

    def __init__(
        self,
        message: str = "Bhashini API request failed",
        status_code: int | None = None,
    ) -> None:
        self.status_code = status_code
        detail = f"{message} (HTTP {status_code})" if status_code else message
        super().__init__(detail)


class BhashiniTimeoutError(BhashiniError):
    """Raised when the Bhashini API request times out."""

    def __init__(self, message: str = "Bhashini API request timed out") -> None:
        super().__init__(message)


class BhashiniResponseParseError(BhashiniError):
    """Raised when the Bhashini API response cannot be parsed."""

    def __init__(self, message: str = "Failed to parse Bhashini API response") -> None:
        super().__init__(message)


class AudioValidationError(Exception):
    """Raised when audio input is empty, malformed, or in an unsupported format."""

    def __init__(self, message: str = "Invalid audio data") -> None:
        self.message = message
        super().__init__(self.message)


class UnsupportedLanguageError(Exception):
    """Raised when an unsupported language code is provided."""

    def __init__(self, language: str, message: str | None = None) -> None:
        self.language = language
        self.message = message or f"Unsupported language code: '{language}'"
        super().__init__(self.message)
