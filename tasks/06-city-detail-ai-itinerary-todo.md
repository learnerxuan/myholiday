# Todo: City Detail & AI Itinerary Planner

## Checklist

### Setup
- [ ] Add `OPENAI_API_KEY` and `GOOGLE_PLACES_API_KEY` to `env.local`
- [ ] Install packages: `npm install react-leaflet leaflet leaflet-routing-machine`

### Database
- [ ] Create `chat_sessions` table (`id`, `user_id`, `destination_id`, `status`, `created_at`)
- [ ] Create `chat_messages` table (`id`, `session_id`, `role`, `content`, `created_at`) — `role` constraint: `'user' | 'assistant'` only
- [ ] Create `itineraries` table (`id`, `user_id`, `destination_id`, `session_id`, `title`, `content JSONB`, `created_at`, `updated_at`)

### City Detail Page (`app/destinations/[id]/page.jsx`)
- [ ] Create the page file
- [ ] Fetch destination data from Supabase `destinations` table by ID
- [ ] Display city name and country as the page heading
- [ ] Display city image (or placeholder)
- [ ] Display short description and overview text
- [ ] Display popular attractions and points of interest
- [ ] Display estimated travel costs (from `budget_level`)
- [ ] Display climate and travel style tags using `Badge` components
- [ ] Display weather overview from `avg_temp_monthly` (no API call needed)
- [ ] Add "Start Planning with AI" `Button` (primary) → navigates to `/itinerary?city=[id]`
- [ ] Add external booking links section (opens in new tab with `rel="noopener noreferrer"`)
- [ ] Handle 404 — show friendly error if destination ID does not exist

### AI Planner Page — Layout (`app/itinerary/page.jsx`)
- [ ] Create the page file
- [ ] Read `city` query param; redirect or show error if missing
- [ ] Set up split-pane layout: `ChatWindow` (left 50%) + tabbed right panel (right 50%)
- [ ] Add tab bar: `📋 Itinerary | 🗺 Map | 🏨 Options`
- [ ] Import `MapPanel` with dynamic import + `ssr: false` to prevent Leaflet SSR crash
- [ ] Show destination name in the page header
- [ ] Add "Save & Exit" button in the header

### AI Planner Page — React State (`itinerary/page.jsx`)
- [ ] `messages` — chat history `[{ role, content }]`
- [ ] `itinerary` — `{ day1: [...], day2: [...] }` each item has `{ type, name, time, lat, lng, price, notes, status, booking_url }`
- [ ] `activeTab` — `'itinerary' | 'map' | 'options'`
- [ ] `activeDay` — which day the map is showing
- [ ] `pendingOptions` — hotel/restaurant comparison cards
- [ ] `isLoading` — true while waiting for AI response
- [ ] `toolStatus` — string shown in chat during tool execution (e.g. `"🔍 Searching for hotels..."`)

### Chat Session Management
- [ ] On page load: check for existing `active` session for `(user_id, destination_id)` — resume if found
- [ ] On first message: create `chat_sessions` row (do NOT create on page load)
- [ ] On AI response: save user + assistant messages together (atomic insert — both or neither)
- [ ] On every API request: fetch full message history from `chat_messages`, pass as `messages` array to OpenAI
- [ ] Do NOT store `tool` role messages in DB — server-side only

### Component: `ChatWindow.jsx`
- [ ] Create `components/sections/ChatWindow.jsx`
- [ ] Render user messages right-aligned (amber background)
- [ ] Render AI messages left-aligned (subtle background)
- [ ] Show animated typing indicator when `isLoading` is true
- [ ] Show tool status message (e.g. `"🔍 Searching for hotels in Kyoto..."`) as transient bubble during tool execution
- [ ] Replace status bubble with actual AI response when done
- [ ] Auto-scroll to newest message
- [ ] Text input + send button at the bottom
- [ ] Disable input while `isLoading`
- [ ] Trigger opening message on mount (AI sends first — asks duration + hotel tier using profile)

### Component: `ItineraryPanel.jsx`
- [ ] Create `components/sections/ItineraryPanel.jsx`
- [ ] Group items by day
- [ ] Each item shows icon (`🏨 / 🍽 / 🎯 / 🚌`), name, time, price
- [ ] Confirmed items (`status: 'confirmed'`) shown in green; suggested items in grey
- [ ] "Export to My Plans" button at the bottom

### Component: `MapPanel.jsx`
- [ ] Create `components/sections/MapPanel.jsx`
- [ ] Use `react-leaflet` + OpenStreetMap tiles (no API key)
- [ ] Day filter buttons above map: `All | Day 1 | Day 2 | ...`
- [ ] Render pins per type: amber (hotel), red (restaurant), blue (attraction), grey (transport)
- [ ] Use Leaflet Routing Machine + OSRM to draw route between confirmed stops for the selected day
- [ ] **Do NOT import this component directly in `itinerary/page.jsx`** — must use `dynamic(..., { ssr: false })`

### Component: `OptionsPanel.jsx`
- [ ] Create `components/sections/OptionsPanel.jsx`
- [ ] Display comparison cards: image, name, price, rating, stars, brief notes
- [ ] "Select" button on each card → sends `"I'll take [name]"` to chat → AI confirms → itinerary updates
- [ ] Auto-switch right panel to Options tab when `pendingOptions` has items

### AI Tool Functions (`lib/ai/tools/`)
- [ ] Create `search_hotels.js` — Google Places API `nearbysearch` (type=`lodging`) → returns `[{ name, price_estimate, rating, stars, lat, lng, image_url, booking_url }]`
- [ ] Create `search_restaurants.js` — Google Places API `nearbysearch` (type=`restaurant`) → supports `dietary` keyword filter → returns `[{ name, cuisine, price_level, rating, lat, lng, image_url }]`
- [ ] Create `search_attractions.js` — OpenTripMap `/places/radius` → returns `[{ name, category, description, lat, lng, image_url }]`
- [ ] Create `get_weather.js` — check `destinations.avg_temp_monthly` first; fall back to Open-Meteo API → returns `{ month, avg_temp_c, condition, notes }`
- [ ] Create `estimate_budget.js` — pure JS calculation → returns `{ total_estimate, breakdown: { accommodation, food, activities, misc } }`
- [ ] Create `check_transport.js` — OSRM public API → returns `{ distance_km, duration_min, mode, steps }`

### System Prompt (`lib/ai/system-prompt.js`)
- [ ] Create `lib/ai/system-prompt.js`
- [ ] Inject destination context: city, country, best time to visit, budget level, coordinates
- [ ] Inject user profile: dietary restrictions, accessibility needs, nationality, language
- [ ] Instruct AI: ask at most 2 questions (duration, hotel tier); use profile defaults if user says "dk"
- [ ] Instruct AI: never ask about things already in the profile
- [ ] Instruct AI: return structured JSON with `message`, `itinerary_updates` (array), `options`

### API Route (`app/api/chat/route.js`)
- [ ] Create the route file
- [ ] Accept POST body: `{ message, history, destinationId, userId }`
- [ ] Fetch destination from Supabase
- [ ] Fetch user traveller_profile from Supabase
- [ ] Build system prompt dynamically
- [ ] Send to OpenAI with all 6 tool definitions
- [ ] On `tool_call`: execute matching function from `lib/ai/tools/`; stream tool status message to client
- [ ] Send tool result back to OpenAI; get final structured JSON response
- [ ] Return final JSON to frontend
- [ ] Handle errors gracefully (rate limits, network failures)
- [ ] Never expose `OPENAI_API_KEY` or `GOOGLE_PLACES_API_KEY` to the browser

### Export Flow
- [ ] "Export to My Plans" shows a confirmation `Modal` — "Save this plan to My Plans?"
- [ ] On confirm: prompt for plan title (or auto-generate: `"Kyoto · 5 Days · March 2026"`)
- [ ] Insert new row into `itineraries` table with current `itinerary` state as `content` JSONB
- [ ] Each export always creates a **new row** — never overwrites previous exports
- [ ] Export works on partial itineraries (not all days need to be confirmed)
- [ ] After export: show success confirmation; **keep chat open** — do NOT redirect
- [ ] User can export again after further refinements

### Final Testing
- [ ] Test full flow: city detail → Start Planning → chat → AI generates draft → refine → export
- [ ] Verify `itinerary_updates` array applies multiple items in a single AI response
- [ ] Verify tool status message appears during tool execution and is replaced by real response
- [ ] Verify session resumes correctly on page reload
- [ ] Verify multiple exports create multiple rows (no overwrite)
- [ ] Verify MapPanel loads without SSR errors
- [ ] Test "idk" / "surprise me" → AI falls back to profile defaults
- [ ] Test dietary restriction respected — no non-halal suggestions for halal users
- [ ] Verify API keys are not present in any client-side bundle
- [ ] Test API error handling (bad key, network failure)
