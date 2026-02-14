import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../models/route_leg.dart';

/// Persistent HTML control panels overlaid on the Leaflet map.
/// Uses HTML DOM elements to avoid Flutter platform view z-index issues.
class HtmlControls {
  // DOM containers
  web.HTMLDivElement? _titlePanel;
  web.HTMLDivElement? _controlPanel;
  web.HTMLDivElement? _gpsPanel;
  web.HTMLDivElement? _routeBar;

  // Control button references (for state updates)
  web.HTMLDivElement? _aisBtn;
  web.HTMLDivElement? _seaMapBtn;
  web.HTMLDivElement? _weatherBtn;
  web.HTMLDivElement? _weatherDivider;
  web.HTMLDivElement? _clearBtn;
  web.HTMLDivElement? _clearDivider;
  web.HTMLDivElement? _gpsFollowBtn;
  web.HTMLDivElement? _setDepartBtn;

  // Route bar cache to avoid unnecessary rebuilds
  int _lastRouteLegsCount = -1;
  double _lastTotalDistance = -1;

  // Style constants
  static const _bg = 'rgba(13,31,60,0.87)';
  static const _accent = '#00E5FF';
  static const _border = 'rgba(0,229,255,0.3)';
  static const _shadow = '0 0 8px rgba(0,229,255,0.1)';
  static const _z = '10000';
  static const _font =
      '-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif';

  // --- Helpers ---

  static web.HTMLDivElement _div([String css = '']) {
    final el = web.document.createElement('div') as web.HTMLDivElement;
    if (css.isNotEmpty) el.style.cssText = css;
    return el;
  }

  static void _on(web.HTMLElement el, String event, void Function() fn) {
    el.addEventListener(event, ((JSAny? e) => fn()).toJS);
  }

  static void _hover(web.HTMLDivElement el, String normal, String hover) {
    _on(el, 'mouseenter', () => el.style.background = hover);
    _on(el, 'mouseleave', () => el.style.background = normal);
  }

  // --- Public API ---

  void init({
    required void Function() onAisToggle,
    required void Function() onSeaMapToggle,
    required void Function() onAllWeather,
    required void Function() onClearRoute,
    required void Function() onSettings,
    required void Function() onGpsFollowToggle,
    required void Function() onSetDeparture,
  }) {
    try { _createTitlePanel(); } catch (e) { print('createTitlePanel: $e'); }
    try {
      _createControlPanel(
        onAisToggle: onAisToggle,
        onSeaMapToggle: onSeaMapToggle,
        onAllWeather: onAllWeather,
        onClearRoute: onClearRoute,
        onSettings: onSettings,
      );
    } catch (e) { print('createControlPanel: $e'); }
    try {
      _createGpsPanel(
        onGpsFollowToggle: onGpsFollowToggle,
        onSetDeparture: onSetDeparture,
      );
    } catch (e) { print('createGpsPanel: $e'); }
    try { _createRouteBar(); } catch (e) { print('createRouteBar: $e'); }
  }

  void dispose() {
    _titlePanel?.remove();
    _controlPanel?.remove();
    _gpsPanel?.remove();
    _routeBar?.remove();
  }

  void hide() {
    _titlePanel?.style.display = 'none';
    _controlPanel?.style.display = 'none';
    _gpsPanel?.style.display = 'none';
    _routeBar?.style.display = 'none';
  }

  void show() {
    _titlePanel?.style.display = 'flex';
    _controlPanel?.style.display = 'block';
    // GPS and route bar visibility handled by updateState
  }

  void updateState({
    required bool aisEnabled,
    required bool aisLoading,
    required bool seaMapEnabled,
    required bool weatherLoading,
    required bool hasWaypoints,
    required bool gpsFollowEnabled,
    required bool hasGps,
    required bool hasDeparture,
    required List<RouteLeg> routeLegs,
    required double totalDistanceKm,
    required String totalDurationText,
    required double boatSpeed,
    required String speedUnitLabel,
  }) {
    _updateAisBtn(aisEnabled, aisLoading);
    _updateSeaMapBtn(seaMapEnabled);
    _updateWeatherBtn(hasWaypoints, weatherLoading);
    _updateClearBtn(hasWaypoints);
    _updateGpsPanel(gpsFollowEnabled, hasGps, hasDeparture);
    _updateRouteBar(
      routeLegs: routeLegs,
      totalDistanceKm: totalDistanceKm,
      totalDurationText: totalDurationText,
      boatSpeed: boatSpeed,
      speedUnitLabel: speedUnitLabel,
    );
  }

  // --- Title Panel ---

  void _createTitlePanel() {
    final panel = _div(
        'position:fixed;top:12px;left:12px;z-index:$_z;'
        'padding:8px 14px;background:$_bg;border-radius:12px;'
        'border:0.5px solid $_border;box-shadow:$_shadow;'
        'font-family:$_font;display:flex;align-items:center;'
        'pointer-events:auto;');

    final icon = _div('font-size:18px;margin-right:6px;line-height:1;');
    icon.textContent = '\u26F5';
    panel.appendChild(icon);

    final text = _div(
        'color:$_accent;font-size:16px;font-weight:bold;letter-spacing:1px;');
    text.textContent = 'Boat Navi';
    panel.appendChild(text);

    web.document.body?.appendChild(panel);
    _titlePanel = panel;
  }

  // --- Control Panel ---

  web.HTMLDivElement _ctrlBtn(
    String icon, {
    required void Function() onTap,
    String radius = '0',
  }) {
    final btn = _div(
        'width:44px;height:44px;display:flex;align-items:center;'
        'justify-content:center;cursor:pointer;transition:background 0.15s;'
        'border-radius:$radius;font-size:20px;color:rgba(255,255,255,0.7);');
    btn.textContent = icon;
    _on(btn, 'click', onTap);
    _hover(btn, 'transparent', 'rgba(0,229,255,0.1)');
    return btn;
  }

  web.HTMLDivElement _ctrlDivider() {
    return _div(
        'width:28px;height:0.5px;background:rgba(0,229,255,0.2);margin:0 auto;');
  }

  void _createControlPanel({
    required void Function() onAisToggle,
    required void Function() onSeaMapToggle,
    required void Function() onAllWeather,
    required void Function() onClearRoute,
    required void Function() onSettings,
  }) {
    final panel = _div(
        'position:fixed;top:12px;right:12px;z-index:$_z;'
        'background:$_bg;border-radius:12px;'
        'border:0.5px solid $_border;box-shadow:$_shadow;'
        'font-family:$_font;pointer-events:auto;');

    // AIS
    _aisBtn = _ctrlBtn('\uD83D\uDEA2',
        onTap: onAisToggle, radius: '12px 12px 0 0');
    panel.appendChild(_aisBtn!);
    panel.appendChild(_ctrlDivider());

    // Sea map
    _seaMapBtn = _ctrlBtn('\uD83D\uDDFA\uFE0F', onTap: onSeaMapToggle);
    panel.appendChild(_seaMapBtn!);

    // Weather (hidden initially)
    _weatherDivider = _ctrlDivider();
    _weatherDivider!.style.display = 'none';
    panel.appendChild(_weatherDivider!);
    _weatherBtn = _ctrlBtn('\u2600\uFE0F', onTap: onAllWeather);
    _weatherBtn!.style.display = 'none';
    panel.appendChild(_weatherBtn!);

    // Clear (hidden initially)
    _clearDivider = _ctrlDivider();
    _clearDivider!.style.display = 'none';
    panel.appendChild(_clearDivider!);
    _clearBtn = _ctrlBtn('\uD83D\uDDD1\uFE0F', onTap: onClearRoute);
    _clearBtn!.style.display = 'none';
    panel.appendChild(_clearBtn!);

    // Settings
    panel.appendChild(_ctrlDivider());
    final settingsBtn = _ctrlBtn('\u2699\uFE0F',
        onTap: onSettings, radius: '0 0 12px 12px');
    panel.appendChild(settingsBtn);

    web.document.body?.appendChild(panel);
    _controlPanel = panel;
  }

  // --- GPS Panel ---

  void _createGpsPanel({
    required void Function() onGpsFollowToggle,
    required void Function() onSetDeparture,
  }) {
    final panel = _div(
        'position:fixed;bottom:100px;right:12px;z-index:$_z;'
        'font-family:$_font;pointer-events:auto;display:none;');

    _gpsFollowBtn = _div(
        'width:40px;height:40px;border-radius:50%;'
        'background:$_bg;'
        'border:1px solid rgba(0,229,255,0.5);'
        'box-shadow:0 0 12px 2px rgba(0,229,255,0.3);'
        'display:flex;align-items:center;justify-content:center;'
        'cursor:pointer;font-size:18px;margin-bottom:8px;'
        'transition:background 0.15s,color 0.15s;color:$_accent;');
    _gpsFollowBtn!.textContent = '\u25CB'; // ○
    _on(_gpsFollowBtn!, 'click', onGpsFollowToggle);
    panel.appendChild(_gpsFollowBtn!);

    _setDepartBtn = _div(
        'width:40px;height:40px;border-radius:50%;'
        'background:$_bg;'
        'border:1px solid rgba(0,229,255,0.5);'
        'box-shadow:0 0 12px 2px rgba(0,229,255,0.3);'
        'display:none;align-items:center;justify-content:center;'
        'cursor:pointer;font-size:18px;color:$_accent;');
    _setDepartBtn!.textContent = '\uD83D\uDCCD'; // 📍
    _on(_setDepartBtn!, 'click', onSetDeparture);
    panel.appendChild(_setDepartBtn!);

    web.document.body?.appendChild(panel);
    _gpsPanel = panel;
  }

  // --- Route Info Bar ---

  void _createRouteBar() {
    _routeBar = _div(
        'position:fixed;bottom:0;left:0;right:0;z-index:$_z;'
        'pointer-events:auto;display:none;font-family:$_font;');
    web.document.body?.appendChild(_routeBar!);
  }

  // --- State Update Helpers ---

  void _updateAisBtn(bool enabled, bool loading) {
    if (_aisBtn == null) return;
    if (loading) {
      _aisBtn!.textContent = '\u23F3'; // ⏳
    } else {
      _aisBtn!.textContent = '\uD83D\uDEA2'; // 🚢
    }
    _aisBtn!.style.color = enabled ? _accent : 'rgba(255,255,255,0.7)';
  }

  void _updateSeaMapBtn(bool enabled) {
    if (_seaMapBtn == null) return;
    _seaMapBtn!.style.color = enabled ? _accent : 'rgba(255,255,255,0.7)';
  }

  void _updateWeatherBtn(bool hasWaypoints, bool loading) {
    if (_weatherBtn == null || _weatherDivider == null) return;
    _weatherBtn!.style.display = hasWaypoints ? 'flex' : 'none';
    _weatherDivider!.style.display = hasWaypoints ? 'block' : 'none';
    if (loading) {
      _weatherBtn!.textContent = '\u23F3'; // ⏳
    } else {
      _weatherBtn!.textContent = '\u2600\uFE0F'; // ☀️
    }
  }

  void _updateClearBtn(bool hasWaypoints) {
    if (_clearBtn == null || _clearDivider == null) return;
    _clearBtn!.style.display = hasWaypoints ? 'flex' : 'none';
    _clearDivider!.style.display = hasWaypoints ? 'block' : 'none';
  }

  void _updateGpsPanel(bool followEnabled, bool hasGps, bool hasDeparture) {
    if (_gpsPanel == null) return;
    _gpsPanel!.style.display = hasGps ? 'block' : 'none';

    if (_gpsFollowBtn != null) {
      if (followEnabled) {
        _gpsFollowBtn!.textContent = '\u25C9'; // ◉
        _gpsFollowBtn!.style.background = _accent;
        _gpsFollowBtn!.style.color = '#0D1F3C';
      } else {
        _gpsFollowBtn!.textContent = '\u25CB'; // ○
        _gpsFollowBtn!.style.background = _bg;
        _gpsFollowBtn!.style.color = _accent;
      }
    }

    if (_setDepartBtn != null) {
      _setDepartBtn!.style.display =
          (hasGps && !hasDeparture) ? 'flex' : 'none';
    }
  }

  void _updateRouteBar({
    required List<RouteLeg> routeLegs,
    required double totalDistanceKm,
    required String totalDurationText,
    required double boatSpeed,
    required String speedUnitLabel,
  }) {
    if (_routeBar == null) return;

    if (routeLegs.isEmpty) {
      _routeBar!.style.display = 'none';
      _lastRouteLegsCount = 0;
      _lastTotalDistance = 0;
      return;
    }

    // Skip rebuild if data unchanged
    if (routeLegs.length == _lastRouteLegsCount &&
        totalDistanceKm == _lastTotalDistance) {
      return;
    }
    _lastRouteLegsCount = routeLegs.length;
    _lastTotalDistance = totalDistanceKm;

    _routeBar!.style.display = 'block';

    // Clear and rebuild
    while (_routeBar!.firstChild != null) {
      _routeBar!.removeChild(_routeBar!.firstChild!);
    }

    final container = _div(
        'margin:8px;padding:10px 14px;background:$_bg;border-radius:14px;'
        'border:0.5px solid $_border;box-shadow:$_shadow;');

    // Summary row
    final summary = _div('display:flex;align-items:center;font-size:14px;');

    final routeIcon =
        _div('color:$_accent;font-size:14px;margin-right:6px;');
    routeIcon.textContent = '\uD83D\uDCCF'; // 📏
    summary.appendChild(routeIcon);

    final dist = _div('color:white;font-weight:bold;margin-right:12px;');
    dist.textContent = '${totalDistanceKm.toStringAsFixed(1)} km';
    summary.appendChild(dist);

    final schedIcon =
        _div('color:$_accent;font-size:14px;margin-right:4px;');
    schedIcon.textContent = '\u23F1'; // ⏱
    summary.appendChild(schedIcon);

    final dur = _div('color:white;font-weight:bold;');
    dur.textContent = totalDurationText;
    summary.appendChild(dur);

    summary.appendChild(_div('flex:1;'));

    final speed = _div('color:rgba(0,229,255,0.7);font-size:12px;');
    speed.textContent = '${boatSpeed.toStringAsFixed(0)} $speedUnitLabel';
    summary.appendChild(speed);

    container.appendChild(summary);

    // Legs list
    if (routeLegs.length > 1) {
      container.appendChild(
          _div('height:1px;background:rgba(0,229,255,0.15);margin:8px 0;'));

      final legsBox = _div('max-height:100px;overflow-y:auto;');

      for (final leg in routeLegs) {
        final row =
            _div('display:flex;align-items:center;padding:3px 0;font-size:12px;');

        row.appendChild(_div(
            'width:8px;height:8px;border-radius:50%;background:$_accent;'
            'box-shadow:0 0 4px rgba(0,229,255,0.5);margin-right:8px;flex-shrink:0;'));

        final names = _div(
            'color:rgba(255,255,255,0.7);flex:1;overflow:hidden;'
            'text-overflow:ellipsis;white-space:nowrap;');
        names.textContent =
            '${leg.from.displayName} \u2192 ${leg.to.displayName}';
        row.appendChild(names);

        final info = _div(
            'color:rgba(0,229,255,0.7);white-space:nowrap;margin-left:8px;');
        info.textContent = '${leg.distanceText} / ${leg.durationText}';
        row.appendChild(info);

        legsBox.appendChild(row);
      }

      container.appendChild(legsBox);
    }

    _routeBar!.appendChild(container);
  }
}
