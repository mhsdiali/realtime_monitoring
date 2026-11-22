const apiKey = process.env.FIREBASE_API_KEY ??
  'AIzaSyCVZHK3DX4Ut25d_OsZyS8xhEXQuU3NiaI';
const databaseUrl = process.env.DATABASE_URL ??
  'https://monitoring-sppg-81246-default-rtdb.asia-southeast1.firebasedatabase.app';
const email = process.env.DEVICE_EMAIL;
const password = process.env.DEVICE_PASSWORD;
// Alternatif tanpa password: custom token untuk UID akun perangkat, dibuat
// dengan Admin SDK (createCustomToken). Token hanya berlaku 1 jam untuk login;
// setelah itu simulator memperpanjang sesi dengan refresh token seperti biasa.
const customToken = process.env.DEVICE_CUSTOM_TOKEN;
const latestIntervalMs = Number(process.env.LATEST_INTERVAL_MS ?? 5000);
const historyIntervalMs = Number(process.env.HISTORY_INTERVAL_MS ?? 1800000);
const ackPollMs = Number(process.env.ACK_POLL_MS ?? 1000);

if (!customToken && (!email || !password)) {
  console.error(
    'Isi DEVICE_EMAIL dan DEVICE_PASSWORD, atau DEVICE_CUSTOM_TOKEN.',
  );
  process.exit(1);
}

let idToken;
let refreshToken;
let uid;
let temperature = 24.5;
let humidity = 55;
let lastHistoryAt = 0;
let acking = false;

async function signInWithCustomToken() {
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: customToken, returnSecureToken: true }),
    },
  );
  const data = await response.json();
  if (!response.ok) {
    throw new Error(`Login gagal: ${data.error?.message ?? response.status}`);
  }
  idToken = data.idToken;
  refreshToken = data.refreshToken;
  const payload = JSON.parse(
    Buffer.from(idToken.split('.')[1], 'base64url').toString('utf8'),
  );
  uid = payload.user_id;
}

async function signIn() {
  if (customToken) {
    return signInWithCustomToken();
  }
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    },
  );
  const data = await response.json();
  if (!response.ok) {
    throw new Error(`Login gagal: ${data.error?.message ?? response.status}`);
  }
  idToken = data.idToken;
  refreshToken = data.refreshToken;
  uid = data.localId;
}

async function refreshIdToken() {
  const response = await fetch(
    `https://securetoken.googleapis.com/v1/token?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'refresh_token',
        refresh_token: refreshToken,
      }),
    },
  );
  const data = await response.json();
  if (!response.ok) {
    throw new Error(`Refresh token gagal: ${data.error?.message ?? response.status}`);
  }
  idToken = data.id_token;
  refreshToken = data.refresh_token;
}

async function put(path, value) {
  const response = await fetch(
    `${databaseUrl}/${path}.json?auth=${encodeURIComponent(idToken)}`,
    {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(value),
    },
  );
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Tulis ${path} gagal: ${response.status} ${text}`);
  }
}

async function get(path) {
  const response = await fetch(
    `${databaseUrl}/${path}.json?auth=${encodeURIComponent(idToken)}`,
  );
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Baca ${path} gagal: ${response.status} ${text}`);
  }
  return response.json();
}

function nextReading() {
  temperature = Math.min(
    39,
    Math.max(10, temperature + (Math.random() - 0.5) * 0.4),
  );
  humidity = Math.min(
    99,
    Math.max(0, humidity + (Math.random() - 0.5) * 1.2),
  );
  return {
    temperature: Number(temperature.toFixed(1)),
    humidity: Number(humidity.toFixed(1)),
    timestamp: Date.now(),
  };
}

async function sendReading(reading) {
  await put('monitoring/latest', reading);
  await put('devices/status/last_seen', reading.timestamp);
}

function formatTime(timestamp) {
  return new Date(timestamp).toLocaleTimeString('id-ID', {
    hour12: false,
    timeZone: 'Asia/Jakarta',
  });
}

function logReading(reading) {
  console.log(
    `[${formatTime(reading.timestamp)} WIB] Data terkirim: ` +
      `${reading.temperature} C, ${reading.humidity}% RH`,
  );
}

async function acknowledgeCommands() {
  if (acking) {
    return;
  }
  acking = true;
  try {
    // Ambil perintah dan ack masing-masing sekali per putaran. Mengecek ack
    // satu per satu membuat satu putaran makin lama seiring bertambahnya
    // perintah tersimpan, sampai melewati batas konfirmasi 5 detik (PRD F5.6).
    const [commands, acknowledgements] = await Promise.all([
      get('devices/ac_control/commands'),
      get('devices/ac_control/acknowledgements'),
    ]);
    if (!commands) {
      return;
    }
    for (const [commandId, command] of Object.entries(commands)) {
      if (acknowledgements?.[commandId]) {
        continue;
      }
      await put(`devices/ac_control/acknowledgements/${commandId}`, {
        status: 'transmitted',
        processed_at: Date.now(),
      });
      console.log(
        `[${formatTime(Date.now())} WIB] Ack perintah ${commandId}: ` +
          `${command?.action ?? '?'}`,
      );
    }
  } catch (error) {
    console.error(error.message);
  } finally {
    acking = false;
  }
}

async function main() {
  await signIn();
  console.log(
    `Login sebagai ${customToken ? 'perangkat (custom token)' : email} ` +
      `(UID ${uid})`,
  );

  if (process.env.DRY_RUN === '1') {
    return;
  }

  const reading = nextReading();
  await sendReading(reading);
  await put(`monitoring/history/${reading.timestamp}`, reading);
  lastHistoryAt = Date.now();
  logReading(reading);
  console.log(
    `Mengirim data setiap ${latestIntervalMs / 1000} detik. ` +
      'Tekan Ctrl+C untuk berhenti.',
  );

  let lastRefreshAt = Date.now();
  setInterval(acknowledgeCommands, ackPollMs);
  acknowledgeCommands();
  setInterval(async () => {
    try {
      if (Date.now() - lastRefreshAt > 50 * 60 * 1000) {
        await refreshIdToken();
        lastRefreshAt = Date.now();
      }
      const next = nextReading();
      await sendReading(next);
      logReading(next);
      if (Date.now() - lastHistoryAt >= historyIntervalMs) {
        await put(`monitoring/history/${next.timestamp}`, next);
        lastHistoryAt = Date.now();
        console.log(
          `[${formatTime(next.timestamp)} WIB] History tersimpan.`,
        );
      }
    } catch (error) {
      console.error(error.message);
    }
  }, latestIntervalMs);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
