class WindowVisibilityPolicy {
  bool _requestedVisible = true;
  bool _fullscreenSuppressed = false;

  bool get requestedVisible => _requestedVisible;
  bool get fullscreenSuppressed => _fullscreenSuppressed;
  bool get shouldBeVisible => _requestedVisible && !_fullscreenSuppressed;

  void requestShow() => _requestedVisible = true;

  void requestHide() => _requestedVisible = false;

  void setFullscreenSuppressed(bool value) => _fullscreenSuppressed = value;
}
