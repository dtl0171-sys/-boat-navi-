import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../models/waypoint.dart';
import '../models/weather_data.dart';
import '../models/marine_data.dart';

/// Overlay UI rendered as HTML DOM elements.
/// Bypasses Flutter's canvas to appear above HtmlElementView platform views.
class HtmlOverlay {
  static web.HTMLElement? _overlay;
  static void Function()? _onDismiss;

  static void dismiss() {
    _overlay?.remove();
    _overlay = null;
    final cb = _onDismiss;
    _onDismiss = null;
    cb?.call();
  }

  // ========== Helpers ==========

  static web.HTMLDivElement _div([String css = '']) {
    final el = web.document.createElement('div') as web.HTMLDivElement;
    if (css.isNotEmpty) el.style.cssText = css;
    return el;
  }

  static web.HTMLDivElement _text(String text, String css) {
    final el = _div(css);
    el.textContent = text;
    return el;
  }

  static void _on(web.HTMLElement el, String event, void Function() fn) {
    el.addEventListener(event, ((JSAny? e) => fn()).toJS);
  }

  static void _onClick(web.HTMLElement el, void Function() fn) {
    el.addEventListener(
        'click',
        ((JSAny? e) {
          // Prevent click from bubbling to backdrop
          fn();
        }).toJS);
  }

  static void _stopClick(web.HTMLElement el) {
    el.addEventListener(
        'click', ((JSAny? e) {}).toJS);
  }

  static web.HTMLDivElement _backdrop({bool center = true}) {
    final el = _div(
        'position:fixed;top:0;left:0;width:100vw;height:100vh;'
        'background:rgba(10,22,40,0.92);z-index:999999;'
        'font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;'
        '${center ? "display:flex;justify-content:center;align-items:center;" : ""}');
    return el;
  }

  static void _hover(web.HTMLDivElement el, String normalBg, String hoverBg) {
    _on(el, 'mouseenter', () => el.style.background = hoverBg);
    _on(el, 'mouseleave', () => el.style.background = normalBg);
  }

  // ========== Waypoint Selector ==========

  static Future<String?> showWaypointSelector(double lat, double lng) {
    dismiss();
    final completer = Completer<String?>();
    _onDismiss = () {
      if (!completer.isCompleted) completer.complete(null);
    };

    final overlay = _backdrop();
    _overlay = overlay;

    void done(String? result) {
      overlay.remove();
      if (_overlay == overlay) {
        _overlay = null;
        _onDismiss = null;
      }
      if (!completer.isCompleted) completer.complete(result);
    }

    _onClick(overlay, () => done(null));

    final dialog = _div(
        'width:260px;padding:20px;background:#0D1F3C;'
        'border-radius:16px;border:0.5px solid rgba(0,229,255,0.5);'
        'box-shadow:0 0 20px rgba(0,229,255,0.2);');
    // Stop clicks on dialog from reaching backdrop
    dialog.addEventListener(
        'click', ((JSAny? e) {}).toJS);

    dialog.appendChild(_text('地点を設定',
        'font-size:16px;font-weight:bold;color:#00E5FF;margin-bottom:2px;'));
    dialog.appendChild(_text(
        '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
        'font-size:11px;color:rgba(255,255,255,0.38);margin-bottom:16px;'));

    void addOpt(String icon, String color, String label, String result) {
      final btn = _div(
          'padding:10px 12px;background:#0A1628;border-radius:8px;'
          'border:0.5px solid ${color}4d;margin-bottom:8px;cursor:pointer;'
          'display:flex;align-items:center;transition:background 0.15s;');
      btn.appendChild(
          _text(icon, 'font-size:20px;color:$color;margin-right:12px;line-height:1;'));
      btn.appendChild(_text(label, 'color:white;font-size:15px;'));
      _onClick(btn, () => done(result));
      _hover(btn, '#0A1628', '#0D2847');
      dialog.appendChild(btn);
    }

    addOpt('\u25B6', '#00E676', '出発地', 'departure');
    addOpt('\u25CF', '#FF9100', '経由地', 'waypoint');
    addOpt('\u2691', '#FF5252', '目的地', 'destination');

    overlay.appendChild(dialog);
    web.document.body?.appendChild(overlay);
    return completer.future;
  }

  // ========== Marker Action ==========

  static Future<String?> showMarkerAction({
    required String name,
    required double lat,
    required double lng,
    WeatherData? weatherData,
    MarineData? marineData,
  }) {
    dismiss();
    final completer = Completer<String?>();
    _onDismiss = () {
      if (!completer.isCompleted) completer.complete(null);
    };

    final overlay = _backdrop(center: false);
    overlay.style.display = 'flex';
    overlay.style.flexDirection = 'column';
    overlay.style.justifyContent = 'flex-end';
    _overlay = overlay;

    void done(String? result) {
      overlay.remove();
      if (_overlay == overlay) {
        _overlay = null;
        _onDismiss = null;
      }
      if (!completer.isCompleted) completer.complete(result);
    }

    _onClick(overlay, () => done(null));

    final panel = _div(
        'background:#0D1F3C;border-radius:20px 20px 0 0;'
        'border-top:0.5px solid rgba(0,229,255,0.5);'
        'border-left:0.5px solid rgba(0,229,255,0.5);'
        'border-right:0.5px solid rgba(0,229,255,0.5);'
        'padding:16px;max-height:70vh;overflow-y:auto;');
    panel.addEventListener('click', ((JSAny? e) {}).toJS);

    // Handle bar
    panel.appendChild(_div(
        'width:40px;height:4px;background:rgba(0,229,255,0.5);'
        'border-radius:2px;margin:0 auto 12px auto;'));

    // Title row
    final titleRow = _div(
        'display:flex;justify-content:space-between;align-items:start;margin-bottom:12px;');
    final titleCol = _div('');
    titleCol.appendChild(_text(name,
        'font-size:18px;font-weight:bold;color:#00E5FF;'));
    titleCol.appendChild(_text(
        '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
        'font-size:12px;color:rgba(255,255,255,0.38);'));
    titleRow.appendChild(titleCol);

    final deleteBtn = _text('\uD83D\uDDD1 削除',
        'color:#FF5252;cursor:pointer;padding:4px 8px;'
        'border:1px solid rgba(255,82,82,0.3);border-radius:8px;'
        'font-size:14px;transition:background 0.15s;white-space:nowrap;');
    _onClick(deleteBtn, () => done('delete'));
    _hover(deleteBtn, '', 'rgba(255,82,82,0.15)');
    titleRow.appendChild(deleteBtn);
    panel.appendChild(titleRow);

    // Weather card
    if (weatherData != null) {
      panel.appendChild(_weatherCardHtml(weatherData));
    } else {
      panel.appendChild(_loadingCardHtml('天気データ読み込み中...'));
    }

    // Marine card
    if (marineData != null) {
      panel.appendChild(_marineCardHtml(marineData));
    } else {
      panel.appendChild(_loadingCardHtml('海洋データ読み込み中...'));
    }

    overlay.appendChild(panel);
    web.document.body?.appendChild(overlay);
    return completer.future;
  }

  // ========== Clear Confirm ==========

  static Future<bool> showClearConfirm() {
    dismiss();
    final completer = Completer<bool>();
    _onDismiss = () {
      if (!completer.isCompleted) completer.complete(false);
    };

    final overlay = _backdrop();
    _overlay = overlay;

    void done(bool result) {
      overlay.remove();
      if (_overlay == overlay) {
        _overlay = null;
        _onDismiss = null;
      }
      if (!completer.isCompleted) completer.complete(result);
    }

    _onClick(overlay, () => done(false));

    final dialog = _div(
        'width:280px;padding:20px;background:#0D1F3C;'
        'border-radius:16px;border:0.5px solid rgba(0,229,255,0.5);');
    dialog.addEventListener('click', ((JSAny? e) {}).toJS);

    dialog.appendChild(_text('ルートクリア',
        'font-size:16px;font-weight:bold;color:#00E5FF;text-align:center;margin-bottom:12px;'));
    dialog.appendChild(_text('すべての地点を削除しますか？',
        'color:rgba(255,255,255,0.7);text-align:center;margin-bottom:20px;'));

    final btnRow = _div('display:flex;justify-content:flex-end;gap:8px;');

    final cancelBtn = _text('キャンセル',
        'color:rgba(255,255,255,0.54);cursor:pointer;padding:8px 16px;'
        'border-radius:8px;font-size:14px;transition:background 0.15s;');
    _onClick(cancelBtn, () => done(false));
    _hover(cancelBtn, '', 'rgba(255,255,255,0.1)');
    btnRow.appendChild(cancelBtn);

    final confirmBtn = _text('クリア',
        'color:#00E5FF;cursor:pointer;padding:8px 16px;'
        'border-radius:8px;font-size:14px;font-weight:bold;transition:background 0.15s;');
    _onClick(confirmBtn, () => done(true));
    _hover(confirmBtn, '', 'rgba(0,229,255,0.15)');
    btnRow.appendChild(confirmBtn);

    dialog.appendChild(btnRow);
    overlay.appendChild(dialog);
    web.document.body?.appendChild(overlay);
    return completer.future;
  }

  // ========== All Weather ==========

  static Future<void> showAllWeather(List<Waypoint> waypoints) {
    dismiss();
    final completer = Completer<void>();
    _onDismiss = () {
      if (!completer.isCompleted) completer.complete();
    };

    final overlay = _backdrop(center: false);
    _overlay = overlay;

    void done() {
      overlay.remove();
      if (_overlay == overlay) {
        _overlay = null;
        _onDismiss = null;
      }
      if (!completer.isCompleted) completer.complete();
    }

    _onClick(overlay, done);

    final panel = _div(
        'position:absolute;top:60px;left:12px;right:12px;bottom:12px;'
        'background:#0D1F3C;border-radius:16px;'
        'border:0.5px solid rgba(0,229,255,0.5);'
        'display:flex;flex-direction:column;overflow:hidden;');
    panel.addEventListener('click', ((JSAny? e) {}).toJS);

    // Header
    final header = _div(
        'display:flex;justify-content:space-between;align-items:center;padding:16px;flex-shrink:0;');
    header.appendChild(_text('全地点の天気情報',
        'font-size:18px;font-weight:bold;color:#00E5FF;'));
    final closeBtn = _text('\u2715',
        'color:rgba(255,255,255,0.54);cursor:pointer;font-size:20px;'
        'padding:4px 8px;border-radius:4px;transition:background 0.15s;');
    _onClick(closeBtn, done);
    _hover(closeBtn, '', 'rgba(255,255,255,0.1)');
    header.appendChild(closeBtn);
    panel.appendChild(header);

    if (waypoints.isEmpty) {
      panel.appendChild(_text('地点がありません',
          'color:rgba(255,255,255,0.54);text-align:center;padding:32px;'));
      overlay.appendChild(panel);
      web.document.body?.appendChild(overlay);
      return completer.future;
    }

    // Tab bar
    final tabBar = _div(
        'display:flex;border-bottom:1px solid rgba(0,229,255,0.2);'
        'overflow-x:auto;flex-shrink:0;');

    // Content container
    final contentContainer = _div('flex:1;overflow-y:auto;padding:16px;');

    final tabs = <web.HTMLDivElement>[];
    final contents = <web.HTMLDivElement>[];

    for (int i = 0; i < waypoints.length; i++) {
      final wp = waypoints[i];

      // Tab header
      final tab = _text(wp.displayName,
          'padding:8px 16px;cursor:pointer;font-size:14px;'
          'border-bottom:2px solid transparent;white-space:nowrap;flex-shrink:0;'
          'color:${i == 0 ? "#00E5FF" : "rgba(255,255,255,0.54)"};'
          '${i == 0 ? "border-bottom-color:#00E5FF;" : ""}');
      tabs.add(tab);

      // Tab content
      final content = _div(i == 0 ? '' : 'display:none;');
      content.appendChild(_text(
          '${wp.position.latitude.toStringAsFixed(4)}, ${wp.position.longitude.toStringAsFixed(4)}',
          'font-size:12px;color:rgba(255,255,255,0.38);margin-bottom:8px;'));

      if (wp.weatherData != null) {
        content.appendChild(_weatherCardHtml(wp.weatherData!));
      } else {
        content.appendChild(_loadingCardHtml('天気データ読み込み中...'));
      }

      if (wp.marineData != null) {
        content.appendChild(_marineCardHtml(wp.marineData!));
      } else {
        content.appendChild(_loadingCardHtml('海洋データ読み込み中...'));
      }

      contents.add(content);
      contentContainer.appendChild(content);

      // Tab click handler
      final idx = i;
      _onClick(tab, () {
        for (int j = 0; j < tabs.length; j++) {
          tabs[j].style.color =
              j == idx ? '#00E5FF' : 'rgba(255,255,255,0.54)';
          tabs[j].style.borderBottomColor =
              j == idx ? '#00E5FF' : 'transparent';
          contents[j].style.display = j == idx ? 'block' : 'none';
        }
      });

      tabBar.appendChild(tab);
    }

    panel.appendChild(tabBar);
    panel.appendChild(contentContainer);
    overlay.appendChild(panel);
    web.document.body?.appendChild(overlay);
    return completer.future;
  }

  // ========== Card builders ==========

  static web.HTMLDivElement _weatherCardHtml(WeatherData data) {
    final card = _div(
        'padding:16px;background:#0A1628;border-radius:12px;'
        'border:0.5px solid rgba(0,229,255,0.3);margin-bottom:8px;');

    card.appendChild(_text('天気',
        'font-size:16px;font-weight:bold;color:#00E5FF;margin-bottom:8px;'));
    card.appendChild(_div(
        'height:1px;background:rgba(0,229,255,0.2);margin-bottom:8px;'));

    final row = _div('display:flex;align-items:center;margin-bottom:8px;');
    row.appendChild(
        _text(data.weatherIcon, 'font-size:32px;margin-right:12px;'));
    final info = _div('');
    info.appendChild(_text(data.weatherDescription,
        'font-size:16px;color:rgba(255,255,255,0.7);'));
    info.appendChild(_text(
        '${data.currentTemperature.toStringAsFixed(1)}\u00B0C',
        'font-size:24px;font-weight:bold;color:white;'));
    row.appendChild(info);
    card.appendChild(row);

    card.appendChild(_infoRowHtml(
        '風速', '${data.currentWindSpeed.toStringAsFixed(1)} km/h'));
    card.appendChild(_infoRowHtml(
        '風向', '${data.currentWindDirection.toStringAsFixed(0)}\u00B0'));
    card.appendChild(_infoRowHtml(
        '降水量', '${data.currentPrecipitation.toStringAsFixed(1)} mm'));

    return card;
  }

  static web.HTMLDivElement _marineCardHtml(MarineData data) {
    final card = _div(
        'padding:16px;background:linear-gradient(135deg,#0A1628,#0D2847);'
        'border-radius:12px;border:0.5px solid rgba(0,229,255,0.3);margin-bottom:8px;');

    card.appendChild(_text('海洋気象',
        'font-size:16px;font-weight:bold;color:#00E5FF;margin-bottom:8px;'));
    card.appendChild(_div(
        'height:1px;background:rgba(0,229,255,0.2);margin-bottom:8px;'));

    card.appendChild(_infoRowHtml(
        '波高', '${data.currentWaveHeight.toStringAsFixed(1)} m'));
    card.appendChild(_infoRowHtml(
        'うねり高', '${data.currentSwellWaveHeight.toStringAsFixed(1)} m'));
    card.appendChild(_infoRowHtml(
        '風浪高', '${data.currentWindWaveHeight.toStringAsFixed(1)} m'));
    card.appendChild(_infoRowHtml(
        '波周期', '${data.currentWavePeriod.toStringAsFixed(1)} s'));
    card.appendChild(_infoRowHtml(
        '波向', '${data.currentWaveDirection.toStringAsFixed(0)}\u00B0'));
    card.appendChild(_infoRowHtml(
        '海面温度',
        '${data.currentSeaSurfaceTemperature.toStringAsFixed(1)}\u00B0C'));

    return card;
  }

  static web.HTMLDivElement _loadingCardHtml(String text) {
    return _text(text,
        'padding:16px;background:#0A1628;border-radius:12px;'
        'border:0.5px solid rgba(0,229,255,0.2);margin-bottom:8px;'
        'color:rgba(255,255,255,0.54);text-align:center;');
  }

  static web.HTMLDivElement _infoRowHtml(String label, String value) {
    final row = _div('display:flex;align-items:center;padding:2px 0;');
    row.appendChild(_text('$label: ',
        'color:rgba(255,255,255,0.54);font-size:13px;margin-right:4px;'));
    row.appendChild(
        _text(value, 'color:white;font-weight:500;font-size:13px;'));
    return row;
  }
}
