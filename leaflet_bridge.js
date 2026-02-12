// Leaflet Bridge - JS side of the Flutter↔Leaflet communication
(function () {
  "use strict";

  var map = null;
  var markerGroup = null;
  var routeLine = null;
  var seaMapLayer = null;
  var seaMapEnabled = false;

  window.LeafletBridge = {
    initMap: function (containerId, lat, lng, zoom) {
      var el = document.getElementById(containerId);
      if (!el || map) return;

      map = L.map(el, {
        center: [lat, lng],
        zoom: zoom,
        zoomControl: false,
      });

      L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
        maxZoom: 19,
        attribution: "&copy; OpenStreetMap contributors",
      }).addTo(map);

      L.control.zoom({ position: "bottomleft" }).addTo(map);

      markerGroup = L.layerGroup().addTo(map);

      map.on("click", function (e) {
        console.log("[LeafletBridge] map click:", e.latlng.lat, e.latlng.lng,
          "_dartOnMapTap exists:", !!window._dartOnMapTap);
        if (window._dartOnMapTap) {
          window._dartOnMapTap(e.latlng.lat, e.latlng.lng);
        }
      });
    },

    updateMarkers: function (markersJson) {
      if (!map || !markerGroup) return;
      markerGroup.clearLayers();

      var markers;
      try {
        markers = JSON.parse(markersJson);
      } catch (e) {
        return;
      }

      for (var i = 0; i < markers.length; i++) {
        var m = markers[i];
        var icon;

        if (m.type === "ais") {
          var svgHtml =
            '<div class="marker-ais" style="transform:rotate(' +
            (m.cog || 0) +
            'deg)">' +
            '<svg width="28" height="28" viewBox="0 0 28 28">' +
            '<path d="M14,0 L22.4,23.8 L14,18.2 L5.6,23.8 Z" ' +
            'fill="#00E5FF" fill-opacity="0.9" />' +
            "</svg></div>";

          icon = L.divIcon({
            html: svgHtml,
            className: "",
            iconSize: [28, 28],
            iconAnchor: [14, 14],
          });

          var aisMarker = L.marker([m.lat, m.lng], { icon: icon });
          var tip =
            "<b>" +
            (m.name || "Unknown") +
            "</b><br>MMSI: " +
            m.mmsi +
            "<br>SOG: " +
            (m.sog || 0).toFixed(1) +
            " kt";
          aisMarker.bindTooltip(tip, {
            className: "ais-tooltip",
            direction: "top",
            offset: [0, -14],
          });
          markerGroup.addLayer(aisMarker);
        } else {
          var cssClass = "marker-" + m.type;
          var label = m.label || "";

          icon = L.divIcon({
            html: '<div class="' + cssClass + '">' + label + "</div>",
            className: "",
            iconSize: [44, 44],
            iconAnchor: [22, 22],
          });

          var marker = L.marker([m.lat, m.lng], { icon: icon });

          if (m.id) {
            (function (id) {
              marker.on("click", function (e) {
                L.DomEvent.stopPropagation(e);
                if (window._dartOnMarkerTap) {
                  window._dartOnMarkerTap(id);
                }
              });
            })(m.id);
          }

          markerGroup.addLayer(marker);
        }
      }
    },

    updateRoute: function (pointsJson) {
      if (!map) return;

      if (routeLine) {
        map.removeLayer(routeLine);
        routeLine = null;
      }

      var points;
      try {
        points = JSON.parse(pointsJson);
      } catch (e) {
        return;
      }

      if (points.length < 2) return;

      var latlngs = [];
      for (var i = 0; i < points.length; i++) {
        latlngs.push([points[i][0], points[i][1]]);
      }

      routeLine = L.polyline(latlngs, {
        color: "#00E5FF",
        weight: 3,
        opacity: 0.8,
      }).addTo(map);
    },

    fitBounds: function (pointsJson) {
      if (!map) return;

      var points;
      try {
        points = JSON.parse(pointsJson);
      } catch (e) {
        return;
      }

      if (points.length === 0) return;

      if (points.length === 1) {
        map.setView([points[0][0], points[0][1]], 10);
        return;
      }

      var bounds = L.latLngBounds();
      for (var i = 0; i < points.length; i++) {
        bounds.extend([points[i][0], points[i][1]]);
      }
      map.fitBounds(bounds, { padding: [50, 50], maxZoom: 14 });
    },

    panTo: function (lat, lng) {
      if (map) map.panTo([lat, lng]);
    },

    setView: function (lat, lng, zoom) {
      if (map) map.setView([lat, lng], zoom);
    },

    toggleSeaMap: function (enabled) {
      if (!map) return;
      seaMapEnabled = enabled;

      if (enabled && !seaMapLayer) {
        seaMapLayer = L.tileLayer(
          "https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png",
          {
            maxZoom: 19,
            opacity: 0.8,
            attribution: "&copy; OpenSeaMap contributors",
          }
        );
        seaMapLayer.addTo(map);
      } else if (!enabled && seaMapLayer) {
        map.removeLayer(seaMapLayer);
        seaMapLayer = null;
      }
    },

    isSeaMapEnabled: function () {
      return seaMapEnabled;
    },

    setMapHidden: function (hidden) {
      var container = document.getElementById("leaflet-map-container");
      if (!container) return;

      // Walk UP the DOM tree from our div, hiding each ancestor,
      // until we reach the Flutter platform view wrapper
      // (the element whose parent is flt-glass-pane or body).
      var el = container;
      while (el) {
        el.style.visibility = hidden ? "hidden" : "";

        var parent = el.parentElement;
        if (!parent || parent === document.body || parent === document.documentElement) {
          break;
        }
        var parentTag = (parent.tagName || "").toUpperCase();
        if (parentTag.indexOf("FLT") === 0) {
          break;
        }
        el = parent;
      }

      // After restoring, Leaflet may need a resize recalc
      if (!hidden && map) {
        setTimeout(function () { map.invalidateSize(); }, 200);
      }
    },

    invalidateSize: function () {
      if (map) {
        setTimeout(function () {
          map.invalidateSize();
        }, 100);
      }
    },

    dispose: function () {
      if (map) {
        map.remove();
        map = null;
        markerGroup = null;
        routeLine = null;
        seaMapLayer = null;
      }
    },
  };
})();
