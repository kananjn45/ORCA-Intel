const map = L.map('map', { zoomControl: false, attributionControl: false }).setView([12.72, 80.42], 10);
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 18 }).addTo(map);

const vessel = [12.80, 80.36], destination = [12.60, 80.70];
const layers = {};
layers.route = L.layerGroup([
  L.polyline([vessel, [12.75, 80.44], [12.68, 80.50], [12.66, 80.59], destination], { color: '#63baff', weight: 5, opacity: .9, lineJoin: 'round' }),
  L.marker(vessel, { icon: L.divIcon({ className: 'vessel-marker', html: '<div class="boat">▲</div>', iconSize: [34, 34] }) }).bindTooltip('Your vessel · 12 kt', { permanent: true, direction: 'bottom', className: 'map-label' }),
  L.circleMarker(destination, { radius: 8, color: '#c8fa62', fillColor: '#c8fa62', fillOpacity: 1 }).bindTooltip('PFZ Sector 04', { permanent: true, direction: 'top', className: 'map-label' })
]).addTo(map);
layers.pfz = L.layerGroup([L.polygon([[12.52, 80.61], [12.56, 80.78], [12.67, 80.75], [12.64, 80.57]], { color: '#c8fa62', fillColor: '#c8fa62', fillOpacity: .16, weight: 2, dashArray: '5 6' }).bindPopup('<b>Potential Fishing Zone</b><br>High chlorophyll front · Active')]).addTo(map);
layers.hazards = L.layerGroup([L.circle([12.88, 80.58], { radius: 7700, color: '#ff9f5a', fillColor: '#ff9f5a', fillOpacity: .25, weight: 2, dashArray: '5 5' }).bindPopup('<b>Weather watch</b><br>Moderate swell window')]).addTo(map);
layers.border = L.layerGroup([L.polyline([[12.38, 80.89], [12.54, 80.83], [12.71, 80.83], [12.91, 80.74], [13.1, 80.69]], { color: '#ff7068', weight: 2, dashArray: '8 9' }).bindTooltip('IMBL · Maintain clearance', { permanent: true, direction: 'right', className: 'border-label' })]).addTo(map);

document.querySelectorAll('.layer').forEach(button => button.addEventListener('click', () => { const key = button.dataset.layer; if (map.hasLayer(layers[key])) { map.removeLayer(layers[key]); button.classList.remove('active') } else { layers[key].addTo(map); button.classList.add('active') } }));
document.getElementById('recenter').onclick = () => map.flyTo(vessel, 11, { duration: .8 });
const sheet = document.getElementById('assistant-sheet');
function openSheet() { sheet.classList.add('open'); sheet.setAttribute('aria-hidden', 'false'); document.getElementById('chat-message').focus() }
function closeSheet() { sheet.classList.remove('open'); sheet.setAttribute('aria-hidden', 'true') }
document.getElementById('voice-button').onclick = openSheet; document.getElementById('safety-button').onclick = openSheet; document.querySelector('.close-sheet').onclick = closeSheet;
document.getElementById('route-button').onclick = () => { map.fitBounds(L.latLngBounds([vessel, destination]), { padding: [65, 35] }); document.querySelector('.route-chip strong').textContent = 'Route guidance active'; };
const log = document.getElementById('chat-log');
function reply(text) { const el = document.createElement('div'); el.className = 'bot-message'; el.textContent = text; log.append(el); log.scrollTop = log.scrollHeight }
document.getElementById('chat-form').addEventListener('submit', e => { e.preventDefault(); const input = document.getElementById('chat-message'); if (!input.value.trim()) return; const user = document.createElement('div'); user.className = 'user-message'; user.textContent = input.value; log.append(user); input.value = ''; setTimeout(() => reply('Current assessment: conditions remain safe. Wind is 12 kt from the north-east, with 0.8 m waves and 18.4 km clearance from the IMBL.'), 350) });
document.querySelectorAll('.quick-prompts button').forEach(b => b.onclick = () => { document.getElementById('chat-message').value = b.textContent; document.getElementById('chat-form').requestSubmit() });
