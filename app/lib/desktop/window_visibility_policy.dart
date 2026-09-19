class WindowVisibilityPolicy {
  bool _requestedVisible = true;
  bool _fullscreenSuppressed = false;
  bool _autoHideSuppressed = false;

  bool get requestedVisible => _requestedVisible;
  bool get fullscreenSuppressed => _fullscreenSuppressed;
  bool get autoHideSuppressed => _autoHideSuppressed;
  bool get shouldBeVisible =>
      _requestedVisible && !_fullscreenSuppressed && !_autoHideSuppressed;

  void requestShow() => _requestedVisible = true;

  void requestHide() => _requestedVisible = false;

  void setFullscreenSuppressed(bool value) => _fullscreenSuppressed = value;

  void setAutoHideSuppressed(bool value) => _autoHideSuppressed = value;
}
