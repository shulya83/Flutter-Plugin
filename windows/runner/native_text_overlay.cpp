#include "native_text_overlay.h"

#include <flutter/standard_method_codec.h>

#include <OleAuto.h>
#include <Psapi.h>

#include <chrono>
#include <cstdint>
#include <iomanip>
#include <sstream>
#include <utility>
#include <vector>

namespace {

constexpr wchar_t kOverlayClassName[] = L"WinTextOverlayDemoWindow";
constexpr int kOverlayWidth = 360;
constexpr int kOverlayHeight = 82;
constexpr int kOverlayGap = 10;

std::string Utf8FromWide(const std::wstring& value) {
  if (value.empty()) {
    return {};
  }

  const int length = WideCharToMultiByte(CP_UTF8, 0, value.data(),
                                         static_cast<int>(value.size()), nullptr,
                                         0, nullptr, nullptr);
  if (length <= 0) {
    return {};
  }

  std::string result(static_cast<size_t>(length), '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.data(),
                      static_cast<int>(value.size()), result.data(), length,
                      nullptr, nullptr);
  return result;
}

std::wstring TruncateForOverlay(const std::wstring& value, size_t max_length) {
  if (value.size() <= max_length) {
    return value;
  }

  return value.substr(0, max_length);
}

}  // namespace

NativeTextOverlay* NativeTextOverlay::active_instance_ = nullptr;

NativeTextOverlay::FocusStreamHandler::FocusStreamHandler(
    NativeTextOverlay* owner)
    : owner_(owner) {}

NativeTextOverlay::FocusStreamHandler::~FocusStreamHandler() = default;

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
NativeTextOverlay::FocusStreamHandler::OnListenInternal(
    const flutter::EncodableValue* arguments,
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) {
  owner_->SetEventSink(std::move(events));
  return nullptr;
}

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
NativeTextOverlay::FocusStreamHandler::OnCancelInternal(
    const flutter::EncodableValue* arguments) {
  owner_->ClearEventSink();
  return nullptr;
}

NativeTextOverlay::NativeTextOverlay(HINSTANCE instance,
                                     HWND owner,
                                     flutter::BinaryMessenger* messenger)
    : instance_(instance), owner_(owner) {
  RegisterChannels(messenger);
}

NativeTextOverlay::~NativeTextOverlay() {
  Stop();
}

void NativeTextOverlay::RegisterChannels(
    flutter::BinaryMessenger* messenger) {
  const auto& codec = flutter::StandardMethodCodec::GetInstance();
  method_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "win_text_overlay_demo/native", &codec);
  event_channel_ =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          messenger, "win_text_overlay_demo/focus_events", &codec);

  method_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "start") {
          result->Success(flutter::EncodableValue(Start()));
          return;
        }
        if (call.method_name() == "stop") {
          Stop();
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (call.method_name() == "refresh") {
          const FocusSnapshot snapshot = CaptureFocusSnapshot();
          SendSnapshot(snapshot);
          result->Success(flutter::EncodableValue(BuildEventMap(snapshot)));
          return;
        }
        result->NotImplemented();
      });

  event_channel_->SetStreamHandler(
      std::make_unique<FocusStreamHandler>(this));
}

bool NativeTextOverlay::Start() {
  if (running_) {
    return true;
  }

  const HRESULT com_result = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  com_initialized_ = SUCCEEDED(com_result);

  const HRESULT automation_result =
      CoCreateInstance(CLSID_CUIAutomation, nullptr, CLSCTX_INPROC_SERVER,
                       IID_PPV_ARGS(&automation_));
  if (FAILED(automation_result) || automation_ == nullptr) {
    if (com_initialized_) {
      CoUninitialize();
      com_initialized_ = false;
    }
    return false;
  }

  active_instance_ = this;
  foreground_hook_ = SetWinEventHook(EVENT_SYSTEM_FOREGROUND,
                                     EVENT_SYSTEM_FOREGROUND, nullptr,
                                     WinEventProc, 0, 0, WINEVENT_OUTOFCONTEXT);
  focus_hook_ = SetWinEventHook(EVENT_OBJECT_FOCUS, EVENT_OBJECT_FOCUS, nullptr,
                                WinEventProc, 0, 0, WINEVENT_OUTOFCONTEXT);
  value_hook_ = SetWinEventHook(EVENT_OBJECT_VALUECHANGE,
                                EVENT_OBJECT_VALUECHANGE, nullptr,
                                WinEventProc, 0, 0, WINEVENT_OUTOFCONTEXT);
  location_hook_ = SetWinEventHook(EVENT_OBJECT_LOCATIONCHANGE,
                                   EVENT_OBJECT_LOCATIONCHANGE, nullptr,
                                   WinEventProc, 0, 0, WINEVENT_OUTOFCONTEXT);

  running_ = foreground_hook_ != nullptr && focus_hook_ != nullptr &&
             value_hook_ != nullptr && location_hook_ != nullptr;
  if (!running_) {
    Stop();
    return false;
  }

  const FocusSnapshot snapshot = CaptureFocusSnapshot();
  SendSnapshot(snapshot);
  return true;
}

void NativeTextOverlay::Stop() {
  if (foreground_hook_) {
    UnhookWinEvent(foreground_hook_);
    foreground_hook_ = nullptr;
  }
  if (focus_hook_) {
    UnhookWinEvent(focus_hook_);
    focus_hook_ = nullptr;
  }
  if (value_hook_) {
    UnhookWinEvent(value_hook_);
    value_hook_ = nullptr;
  }
  if (location_hook_) {
    UnhookWinEvent(location_hook_);
    location_hook_ = nullptr;
  }
  if (overlay_) {
    DestroyWindow(overlay_);
    overlay_ = nullptr;
  }
  if (automation_) {
    automation_->Release();
    automation_ = nullptr;
  }
  if (com_initialized_) {
    CoUninitialize();
    com_initialized_ = false;
  }
  if (active_instance_ == this) {
    active_instance_ = nullptr;
  }
  running_ = false;
}

void NativeTextOverlay::SetEventSink(
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> events) {
  event_sink_ = std::move(events);
  if (running_) {
    SendSnapshot(CaptureFocusSnapshot());
  }
}

void NativeTextOverlay::ClearEventSink() {
  event_sink_.reset();
}

void CALLBACK NativeTextOverlay::WinEventProc(HWINEVENTHOOK hook,
                                              DWORD event,
                                              HWND hwnd,
                                              LONG object_id,
                                              LONG child_id,
                                              DWORD event_thread,
                                              DWORD event_time) {
  if (active_instance_) {
    active_instance_->OnWinEvent(event, hwnd, object_id);
  }
}

void NativeTextOverlay::OnWinEvent(DWORD event, HWND hwnd, LONG object_id) {
  if (hwnd == overlay_) {
    return;
  }
  if (event == EVENT_OBJECT_LOCATIONCHANGE && object_id != OBJID_CARET) {
    return;
  }

  const FocusSnapshot snapshot = CaptureFocusSnapshot();
  SendSnapshot(snapshot);
}

NativeTextOverlay::FocusSnapshot NativeTextOverlay::CaptureFocusSnapshot() {
  LARGE_INTEGER frequency = {};
  LARGE_INTEGER started = {};
  QueryPerformanceFrequency(&frequency);
  QueryPerformanceCounter(&started);

  FocusSnapshot snapshot;
  const HWND foreground = GetForegroundWindow();
  DWORD process_id = 0;
  GetWindowThreadProcessId(foreground, &process_id);

  snapshot.app_title = GetWindowTextValue(foreground);
  snapshot.process_name = GetProcessName(process_id);
  snapshot.window_class = GetClassNameValue(foreground);
  snapshot.hwnd_text = FormatHwnd(foreground);
  snapshot.caret_rect = GetCaretRect(foreground);

  IUIAutomationElement* element = nullptr;
  if (automation_ &&
      SUCCEEDED(automation_->GetFocusedElement(&element)) && element) {
    BSTR name = nullptr;
    if (SUCCEEDED(element->get_CurrentName(&name))) {
      snapshot.control_name = GetBstrProperty(name);
    }

    CONTROLTYPEID control_type = 0;
    if (SUCCEEDED(element->get_CurrentControlType(&control_type))) {
      snapshot.control_type = GetControlTypeName(control_type);
      snapshot.is_text_input =
          control_type == UIA_EditControlTypeId ||
          control_type == UIA_DocumentControlTypeId ||
          control_type == UIA_ComboBoxControlTypeId;
    }

    snapshot.element_rect = GetElementRect(element);

    VARIANT password_property;
    VariantInit(&password_property);
    if (SUCCEEDED(element->GetCurrentPropertyValue(UIA_IsPasswordPropertyId,
                                                   &password_property)) &&
        password_property.vt == VT_BOOL) {
      snapshot.is_password = password_property.boolVal == VARIANT_TRUE;
    }
    VariantClear(&password_property);

    IUnknown* unknown_pattern = nullptr;
    if (!snapshot.is_password &&
        SUCCEEDED(element->GetCurrentPattern(UIA_ValuePatternId,
                                             &unknown_pattern)) &&
        unknown_pattern) {
      IUIAutomationValuePattern* value_pattern = nullptr;
      if (SUCCEEDED(unknown_pattern->QueryInterface(
              IID_PPV_ARGS(&value_pattern))) &&
          value_pattern) {
        BSTR value = nullptr;
        if (SUCCEEDED(value_pattern->get_CurrentValue(&value))) {
          snapshot.value = GetBstrProperty(value);
          snapshot.is_text_input = true;
        }
        value_pattern->Release();
      }
      unknown_pattern->Release();
    }

    element->Release();
  }

  snapshot.overlay_visible =
      snapshot.is_text_input && RectHasArea(snapshot.element_rect);
  last_snapshot_ = snapshot;
  UpdateOverlay(snapshot);

  LARGE_INTEGER ended = {};
  QueryPerformanceCounter(&ended);
  if (frequency.QuadPart > 0) {
    snapshot.latency_micros =
        static_cast<int64_t>((ended.QuadPart - started.QuadPart) * 1000000 /
                             frequency.QuadPart);
  }
  last_snapshot_ = snapshot;
  return snapshot;
}

NativeTextOverlay::NativeRect NativeTextOverlay::GetElementRect(
    IUIAutomationElement* element) const {
  RECT rect = {};
  if (SUCCEEDED(element->get_CurrentBoundingRectangle(&rect)) &&
      rect.right > rect.left && rect.bottom > rect.top) {
    return {true, rect.left, rect.top, rect.right, rect.bottom};
  }
  return {};
}

NativeTextOverlay::NativeRect NativeTextOverlay::GetCaretRect(
    HWND foreground) const {
  if (!foreground) {
    return {};
  }

  const DWORD thread_id = GetWindowThreadProcessId(foreground, nullptr);
  GUITHREADINFO info = {};
  info.cbSize = sizeof(info);
  if (!GetGUIThreadInfo(thread_id, &info) || !info.hwndCaret) {
    return {};
  }

  RECT rect = info.rcCaret;
  POINT points[2] = {{rect.left, rect.top}, {rect.right, rect.bottom}};
  MapWindowPoints(info.hwndCaret, nullptr, points, 2);
  rect.left = points[0].x;
  rect.top = points[0].y;
  rect.right = points[1].x;
  rect.bottom = points[1].y;

  if (rect.right <= rect.left) {
    rect.right = rect.left + 1;
  }
  if (rect.bottom <= rect.top) {
    rect.bottom = rect.top + 18;
  }
  return {true, rect.left, rect.top, rect.right, rect.bottom};
}

std::wstring NativeTextOverlay::GetControlTypeName(
    CONTROLTYPEID control_type) const {
  switch (control_type) {
    case UIA_EditControlTypeId:
      return L"Edit";
    case UIA_DocumentControlTypeId:
      return L"Document";
    case UIA_ComboBoxControlTypeId:
      return L"ComboBox";
    case UIA_PaneControlTypeId:
      return L"Pane";
    case UIA_WindowControlTypeId:
      return L"Window";
    case UIA_TextControlTypeId:
      return L"Text";
    case UIA_ButtonControlTypeId:
      return L"Button";
    case UIA_ListControlTypeId:
      return L"List";
    case UIA_ListItemControlTypeId:
      return L"ListItem";
    default:
      return L"Unknown";
  }
}

std::wstring NativeTextOverlay::GetBstrProperty(BSTR value) const {
  if (!value) {
    return {};
  }

  std::wstring result(value, SysStringLen(value));
  SysFreeString(value);
  return result;
}

std::wstring NativeTextOverlay::GetWindowTextValue(HWND hwnd) const {
  if (!hwnd) {
    return {};
  }

  const int length = GetWindowTextLengthW(hwnd);
  if (length <= 0) {
    return {};
  }

  std::wstring text(static_cast<size_t>(length + 1), L'\0');
  const int copied = GetWindowTextW(hwnd, text.data(), length + 1);
  text.resize(static_cast<size_t>(copied));
  return text;
}

std::wstring NativeTextOverlay::GetClassNameValue(HWND hwnd) const {
  if (!hwnd) {
    return {};
  }

  wchar_t buffer[256] = {};
  const int length = GetClassNameW(
      hwnd, buffer, static_cast<int>(sizeof(buffer) / sizeof(buffer[0])));
  if (length <= 0) {
    return {};
  }
  return std::wstring(buffer, static_cast<size_t>(length));
}

std::wstring NativeTextOverlay::GetProcessName(DWORD process_id) const {
  if (process_id == 0) {
    return {};
  }

  HANDLE process =
      OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, process_id);
  if (!process) {
    return {};
  }

  std::vector<wchar_t> path(32768);
  DWORD size = static_cast<DWORD>(path.size());
  std::wstring process_name;
  if (QueryFullProcessImageNameW(process, 0, path.data(), &size) && size > 0) {
    std::wstring full_path(path.data(), size);
    const size_t slash = full_path.find_last_of(L"\\/");
    process_name = slash == std::wstring::npos ? full_path
                                               : full_path.substr(slash + 1);
  }
  CloseHandle(process);
  return process_name;
}

std::wstring NativeTextOverlay::FormatHwnd(HWND hwnd) const {
  if (!hwnd) {
    return {};
  }

  std::wstringstream stream;
  stream << L"0x" << std::uppercase << std::hex
         << reinterpret_cast<uintptr_t>(hwnd);
  return stream.str();
}

bool NativeTextOverlay::RectHasArea(const NativeRect& rect) const {
  return rect.valid && rect.right > rect.left && rect.bottom > rect.top;
}

flutter::EncodableMap NativeTextOverlay::BuildRectMap(
    const NativeRect& rect) const {
  return {
      {flutter::EncodableValue("valid"), flutter::EncodableValue(rect.valid)},
      {flutter::EncodableValue("left"),
       flutter::EncodableValue(static_cast<int32_t>(rect.left))},
      {flutter::EncodableValue("top"),
       flutter::EncodableValue(static_cast<int32_t>(rect.top))},
      {flutter::EncodableValue("right"),
       flutter::EncodableValue(static_cast<int32_t>(rect.right))},
      {flutter::EncodableValue("bottom"),
       flutter::EncodableValue(static_cast<int32_t>(rect.bottom))},
  };
}

flutter::EncodableMap NativeTextOverlay::BuildEventMap(
    const FocusSnapshot& snapshot) const {
  return {
      {flutter::EncodableValue("appTitle"),
       flutter::EncodableValue(Utf8FromWide(snapshot.app_title))},
      {flutter::EncodableValue("processName"),
       flutter::EncodableValue(Utf8FromWide(snapshot.process_name))},
      {flutter::EncodableValue("windowClass"),
       flutter::EncodableValue(Utf8FromWide(snapshot.window_class))},
      {flutter::EncodableValue("controlName"),
       flutter::EncodableValue(Utf8FromWide(snapshot.control_name))},
      {flutter::EncodableValue("controlType"),
       flutter::EncodableValue(Utf8FromWide(snapshot.control_type))},
      {flutter::EncodableValue("value"),
       flutter::EncodableValue(Utf8FromWide(snapshot.value))},
      {flutter::EncodableValue("hwnd"),
       flutter::EncodableValue(Utf8FromWide(snapshot.hwnd_text))},
      {flutter::EncodableValue("elementRect"),
       flutter::EncodableValue(BuildRectMap(snapshot.element_rect))},
      {flutter::EncodableValue("caretRect"),
       flutter::EncodableValue(BuildRectMap(snapshot.caret_rect))},
      {flutter::EncodableValue("isPassword"),
       flutter::EncodableValue(snapshot.is_password)},
      {flutter::EncodableValue("isTextInput"),
       flutter::EncodableValue(snapshot.is_text_input)},
      {flutter::EncodableValue("overlayVisible"),
       flutter::EncodableValue(snapshot.overlay_visible)},
      {flutter::EncodableValue("latencyMicros"),
       flutter::EncodableValue(snapshot.latency_micros)},
  };
}

void NativeTextOverlay::SendSnapshot(const FocusSnapshot& snapshot) {
  if (!event_sink_) {
    return;
  }

  event_sink_->Success(flutter::EncodableValue(BuildEventMap(snapshot)));
}

bool NativeTextOverlay::EnsureOverlayWindow() {
  if (overlay_) {
    return true;
  }

  WNDCLASSW window_class = {};
  window_class.lpfnWndProc = OverlayWndProc;
  window_class.hInstance = instance_;
  window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
  window_class.lpszClassName = kOverlayClassName;
  RegisterClassW(&window_class);

  overlay_ = CreateWindowExW(
      WS_EX_LAYERED | WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW | WS_EX_TOPMOST |
          WS_EX_TRANSPARENT,
      kOverlayClassName, L"", WS_POPUP, 0, 0, kOverlayWidth, kOverlayHeight,
      owner_, nullptr, instance_, this);
  if (!overlay_) {
    return false;
  }

  SetLayeredWindowAttributes(overlay_, 0, 238, LWA_ALPHA);
  return true;
}

void NativeTextOverlay::UpdateOverlay(const FocusSnapshot& snapshot) {
  if (!snapshot.overlay_visible) {
    if (overlay_) {
      ShowWindow(overlay_, SW_HIDE);
    }
    return;
  }

  if (!EnsureOverlayWindow()) {
    return;
  }

  const NativeRect rect = RectHasArea(snapshot.caret_rect)
                              ? snapshot.caret_rect
                              : snapshot.element_rect;
  int x = static_cast<int>(rect.left);
  int y = static_cast<int>(rect.top) - kOverlayHeight - kOverlayGap;
  if (y < 0) {
    y = static_cast<int>(rect.bottom) + kOverlayGap;
  }

  SetWindowPos(overlay_, HWND_TOPMOST, x, y, kOverlayWidth, kOverlayHeight,
               SWP_NOACTIVATE | SWP_SHOWWINDOW);
  InvalidateRect(overlay_, nullptr, TRUE);
}

LRESULT CALLBACK NativeTextOverlay::OverlayWndProc(HWND hwnd,
                                                   UINT message,
                                                   WPARAM wparam,
                                                   LPARAM lparam) {
  if (message == WM_NCCREATE) {
    const auto* create_struct = reinterpret_cast<CREATESTRUCTW*>(lparam);
    SetWindowLongPtrW(
        hwnd, GWLP_USERDATA,
        reinterpret_cast<LONG_PTR>(create_struct->lpCreateParams));
  }

  auto* overlay = reinterpret_cast<NativeTextOverlay*>(
      GetWindowLongPtrW(hwnd, GWLP_USERDATA));
  if (overlay && message == WM_PAINT) {
    overlay->PaintOverlay(hwnd);
    return 0;
  }

  return DefWindowProcW(hwnd, message, wparam, lparam);
}

void NativeTextOverlay::PaintOverlay(HWND hwnd) {
  PAINTSTRUCT paint = {};
  HDC dc = BeginPaint(hwnd, &paint);

  RECT bounds = {};
  GetClientRect(hwnd, &bounds);
  HBRUSH background = CreateSolidBrush(RGB(19, 23, 28));
  FillRect(dc, &bounds, background);
  DeleteObject(background);

  HPEN border = CreatePen(PS_SOLID, 1, RGB(85, 199, 139));
  HGDIOBJ old_pen = SelectObject(dc, border);
  HGDIOBJ old_brush = SelectObject(dc, GetStockObject(NULL_BRUSH));
  Rectangle(dc, bounds.left, bounds.top, bounds.right - 1, bounds.bottom - 1);
  SelectObject(dc, old_brush);
  SelectObject(dc, old_pen);
  DeleteObject(border);

  SetBkMode(dc, TRANSPARENT);
  SetTextColor(dc, RGB(85, 199, 139));
  HFONT label_font = CreateFontW(-14, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
                                 DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
                                 CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                                 DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
  HGDIOBJ old_font = SelectObject(dc, label_font);
  RECT label_rect = {14, 10, kOverlayWidth - 14, 28};
  DrawTextW(dc, L"Text input detected", -1, &label_rect,
            DT_SINGLELINE | DT_END_ELLIPSIS);

  SetTextColor(dc, RGB(238, 242, 247));
  HFONT value_font = CreateFontW(-13, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
                                 DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
                                 CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                                 DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
  SelectObject(dc, value_font);

  std::wstring title = last_snapshot_.control_name.empty()
                           ? last_snapshot_.process_name
                           : last_snapshot_.control_name;
  RECT title_rect = {14, 32, kOverlayWidth - 14, 50};
  DrawTextW(dc, title.c_str(), -1, &title_rect,
            DT_SINGLELINE | DT_END_ELLIPSIS);

  std::wstring value =
      last_snapshot_.is_password
          ? L"Protected field"
          : TruncateForOverlay(last_snapshot_.value, 80);
  RECT value_rect = {14, 54, kOverlayWidth - 14, 74};
  DrawTextW(dc, value.c_str(), -1, &value_rect,
            DT_SINGLELINE | DT_END_ELLIPSIS);

  SelectObject(dc, old_font);
  DeleteObject(value_font);
  DeleteObject(label_font);
  EndPaint(hwnd, &paint);
}
