#ifndef RUNNER_NATIVE_TEXT_OVERLAY_H_
#define RUNNER_NATIVE_TEXT_OVERLAY_H_

#include <UIAutomation.h>
#include <Windows.h>

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler.h>
#include <flutter/method_channel.h>

#include <memory>
#include <string>

class NativeTextOverlay {
 public:
  NativeTextOverlay(HINSTANCE instance,
                    HWND owner,
                    flutter::BinaryMessenger* messenger);
  ~NativeTextOverlay();

  NativeTextOverlay(const NativeTextOverlay&) = delete;
  NativeTextOverlay& operator=(const NativeTextOverlay&) = delete;

  bool Start();
  void Stop();
  void SetEventSink(
      std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> events);
  void ClearEventSink();

 private:
  struct NativeRect {
    bool valid = false;
    LONG left = 0;
    LONG top = 0;
    LONG right = 0;
    LONG bottom = 0;
  };

  struct FocusSnapshot {
    std::wstring app_title;
    std::wstring process_name;
    std::wstring window_class;
    std::wstring control_name;
    std::wstring control_type;
    std::wstring value;
    std::wstring hwnd_text;
    NativeRect element_rect;
    NativeRect caret_rect;
    bool is_password = false;
    bool is_text_input = false;
    bool overlay_visible = false;
    int64_t latency_micros = 0;
  };

  class FocusStreamHandler
      : public flutter::StreamHandler<flutter::EncodableValue> {
   public:
    explicit FocusStreamHandler(NativeTextOverlay* owner);
    ~FocusStreamHandler() override;

   protected:
    std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
    OnListenInternal(
        const flutter::EncodableValue* arguments,
        std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
        override;

    std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
    OnCancelInternal(const flutter::EncodableValue* arguments) override;

   private:
    NativeTextOverlay* owner_;
  };

  static void CALLBACK WinEventProc(HWINEVENTHOOK hook,
                                    DWORD event,
                                    HWND hwnd,
                                    LONG object_id,
                                    LONG child_id,
                                    DWORD event_thread,
                                    DWORD event_time);
  static LRESULT CALLBACK OverlayWndProc(HWND hwnd,
                                          UINT message,
                                          WPARAM wparam,
                                          LPARAM lparam);

  void RegisterChannels(flutter::BinaryMessenger* messenger);
  void OnWinEvent(DWORD event, HWND hwnd, LONG object_id);
  FocusSnapshot CaptureFocusSnapshot();
  void SendSnapshot(const FocusSnapshot& snapshot);
  void UpdateOverlay(const FocusSnapshot& snapshot);
  bool EnsureOverlayWindow();
  void PaintOverlay(HWND hwnd);

  NativeRect GetElementRect(IUIAutomationElement* element) const;
  NativeRect GetCaretRect(HWND foreground) const;
  std::wstring GetControlTypeName(CONTROLTYPEID control_type) const;
  std::wstring GetBstrProperty(BSTR value) const;
  std::wstring GetWindowTextValue(HWND hwnd) const;
  std::wstring GetClassNameValue(HWND hwnd) const;
  std::wstring GetProcessName(DWORD process_id) const;
  std::wstring FormatHwnd(HWND hwnd) const;
  bool RectHasArea(const NativeRect& rect) const;
  flutter::EncodableMap BuildEventMap(const FocusSnapshot& snapshot) const;
  flutter::EncodableMap BuildRectMap(const NativeRect& rect) const;

  HINSTANCE instance_ = nullptr;
  HWND owner_ = nullptr;
  HWND overlay_ = nullptr;
  HWINEVENTHOOK foreground_hook_ = nullptr;
  HWINEVENTHOOK focus_hook_ = nullptr;
  HWINEVENTHOOK value_hook_ = nullptr;
  HWINEVENTHOOK location_hook_ = nullptr;
  IUIAutomation* automation_ = nullptr;
  bool com_initialized_ = false;
  bool running_ = false;
  FocusSnapshot last_snapshot_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      method_channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>>
      event_channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;

  static NativeTextOverlay* active_instance_;
};

#endif  // RUNNER_NATIVE_TEXT_OVERLAY_H_
