const map = L.map('map', { zoomControl: false, attributionControl: false }).setView([12.72, 80.42], 10);
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 18 }).addTo(map);

const vessel = [12.80, 80.36];
const layers = {};
const routeLayer = L.featureGroup().addTo(map);
layers.route = routeLayer;

function pointFromGeoJson(coordinate) {
  return [coordinate[1], coordinate[0]];
}

function routeCoordinates(geoJson) {
  const feature = geoJson?.type === 'Feature' ? geoJson : geoJson?.features?.find(({ geometry }) =>
    geometry?.type === 'LineString' || geometry?.type === 'MultiLineString');
  const geometry = feature?.geometry || (geoJson?.type === 'LineString' || geoJson?.type === 'MultiLineString' ? geoJson : null);
  if (!geometry) return [];
  if (geometry.type === 'LineString') return geometry.coordinates.map(pointFromGeoJson);
  return geometry.type === 'MultiLineString' ? geometry.coordinates.flat().map(pointFromGeoJson) : [];
}

function setRoute(geoJson) {
  const coordinates = routeCoordinates(geoJson);
  if (coordinates.length < 2) throw new Error('Route response does not contain a GeoJSON LineString.');
  routeLayer.clearLayers();
  L.polyline(coordinates, { color: '#63baff', weight: 5, opacity: .9, lineJoin: 'round' }).addTo(routeLayer);
  L.marker(coordinates[0], { icon: L.divIcon({ className: 'vessel-marker', html: '<div class="boat">▲</div>', iconSize: [34, 34] }) })
    .bindTooltip('Your vessel · live position', { permanent: true, direction: 'bottom', className: 'map-label' }).addTo(routeLayer);
  L.circleMarker(coordinates.at(-1), { radius: 8, color: '#c8fa62', fillColor: '#c8fa62', fillOpacity: 1 })
    .bindTooltip('Route destination', { permanent: true, direction: 'top', className: 'map-label' }).addTo(routeLayer);
  const routeName = geoJson?.properties?.name || geoJson?.features?.[0]?.properties?.name || 'Backend route active';
  document.querySelector('.route-chip strong').textContent = routeName;
  map.fitBounds(L.latLngBounds(coordinates), { padding: [65, 35], maxZoom: 12 });
}

async function loadRoute() {
  const endpoint = document.querySelector('.map-panel').dataset.routeApi;
  try {
    const response = await fetch(endpoint, { headers: { Accept: 'application/geo+json, application/json' } });
    if (!response.ok) throw new Error(`Route service returned ${response.status}`);
    setRoute(await response.json());
  } catch (error) {
    // Never manufacture route waypoints on the client: that can be unsafe.
    document.querySelector('.route-chip strong').textContent = 'Route unavailable';
    console.warn('Unable to load navigation GeoJSON:', error);
  }
}

layers.pfz = L.layerGroup([L.polygon([[12.52, 80.61], [12.56, 80.78], [12.67, 80.75], [12.64, 80.57]], { color: '#c8fa62', fillColor: '#c8fa62', fillOpacity: .16, weight: 2, dashArray: '5 6' }).bindPopup('<b>Potential Fishing Zone</b><br>High chlorophyll front · Active')]).addTo(map);

// All significant wave-height cells at or above 2 m become a pulsing heatmap.
const waveRiskCells = [
  { position: [12.88, 80.58], radius: 7500, waveHeight: 2.4 },
  { position: [12.94, 80.51], radius: 4600, waveHeight: 2.9 },
  { position: [12.82, 80.67], radius: 5200, waveHeight: 2.1 }
];
layers.hazards = L.layerGroup(waveRiskCells.filter(cell => cell.waveHeight >= 2).map(cell =>
  L.circle(cell.position, { radius: cell.radius, color: '#ff9f5a', fillColor: '#ff9f5a', fillOpacity: .24, weight: 2, className: 'weather-risk-cell' })
    .bindPopup(`<b>High wave risk</b><br>Significant wave height: ${cell.waveHeight.toFixed(1)} m`)
)).addTo(map);
layers.border = L.layerGroup([L.polyline([[12.38, 80.89], [12.54, 80.83], [12.71, 80.83], [12.91, 80.74], [13.1, 80.69]], { color: '#ff7068', weight: 2, dashArray: '8 9' }).bindTooltip('IMBL · Maintain clearance', { permanent: true, direction: 'right', className: 'border-label' })]).addTo(map);

document.querySelectorAll('.layer').forEach(button => button.addEventListener('click', () => { const key = button.dataset.layer; if (map.hasLayer(layers[key])) { map.removeLayer(layers[key]); button.classList.remove('active') } else { layers[key].addTo(map); button.classList.add('active') } }));
document.getElementById('recenter').onclick = () => map.flyTo(vessel, 11, { duration: .8 });
document.getElementById('route-button').onclick = () => { if (routeLayer.getLayers().length) map.fitBounds(routeLayer.getBounds(), { padding: [65, 35] }); else loadRoute(); };

const sheet = document.getElementById('assistant-sheet');
function openSheet() { sheet.classList.add('open'); sheet.setAttribute('aria-hidden', 'false'); document.getElementById('chat-message').focus() }
function closeSheet() { sheet.classList.remove('open'); sheet.setAttribute('aria-hidden', 'true') }
document.getElementById('voice-button').onclick = openSheet; document.getElementById('safety-button').onclick = openSheet; document.querySelector('.close-sheet').onclick = closeSheet;
const log = document.getElementById('chat-log');
function reply(text) { const el = document.createElement('div'); el.className = 'bot-message'; el.textContent = text; log.append(el); log.scrollTop = log.scrollHeight }
document.getElementById('chat-form').addEventListener('submit', e => { e.preventDefault(); const input = document.getElementById('chat-message'); if (!input.value.trim()) return; const user = document.createElement('div'); user.className = 'user-message'; user.textContent = input.value; log.append(user); input.value = ''; setTimeout(() => reply('Current assessment: conditions remain safe. Wind is 12 kt from the north-east, with 0.8 m waves and 18.4 km clearance from the IMBL.'), 350) });
document.querySelectorAll('.quick-prompts button').forEach(b => b.onclick = () => { document.getElementById('chat-message').value = b.textContent; document.getElementById('chat-form').requestSubmit() });
loadRoute();
