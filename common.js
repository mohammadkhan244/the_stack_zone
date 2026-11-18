import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm";

const C = window.STACK_ZONE_CONFIG || {};
export const configured = C.SUPABASE_URL && !C.SUPABASE_URL.includes("YOUR-PROJECT");
export const sb = configured ? createClient(C.SUPABASE_URL, C.SUPABASE_ANON_KEY) : null;

export const $ = (s, el = document) => el.querySelector(s);
export const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
export const LIVE_MS = 2 * 60 * 60 * 1000;
export const isOn = (l) => !l.ended && Date.now() - new Date(l.added_at).getTime() < LIVE_MS;

const PALETTE = [["#7a2cff","#ff3d7f"],["#00a2ff","#0047ff"],["#ff9d00","#ff4e00"],["#00b86b","#006b5a"],["#d6336c","#5f0f40"],["#5c7cfa","#1c1f5c"],["#f03e3e","#862e9c"],["#fab005","#e8590c"]];
export function colors(seed) { let h = 0; for (const c of String(seed)) h = (h * 31 + c.charCodeAt(0)) >>> 0; return PALETTE[h % PALETTE.length]; }
export const initials = (n) => String(n).split(/[\s&]+/).filter(Boolean).slice(0, 2).map((w) => w[0]).join("").toUpperCase() || "★";

// Guess a creator name from a Substack URL (subdomain or @handle)
export function guessCreator(url) {
  try {
    const u = new URL(url);
    const at = u.pathname.match(/@([\w.-]+)/); if (at) return at[1];
    const sub = u.hostname.match(/^([\w-]+)\.substack\.com$/); if (sub && !["open", "www"].includes(sub[1])) return sub[1];
  } catch {}
  return "";
}

export function since(ts) {
  const s = Math.max(0, (Date.now() - new Date(ts).getTime()) / 1000 | 0);
  return `${s / 60 | 0}:${String(s % 60).padStart(2, "0")}`;
}

// ---- The hype guy ----
let sound = true, ac;
export const setSound = (v) => { sound = v; if (!v) speechSynthesis?.cancel(); };
export const soundOn = () => sound;
function horn() {
  if (!sound) return;
  try {
    ac = ac || new (window.AudioContext || window.webkitAudioContext)();
    const t = ac.currentTime;
    [220, 277, 330].forEach((f) => {
      const o = ac.createOscillator(), g = ac.createGain();
      o.type = "sawtooth"; o.frequency.value = f;
      g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.12, t + 0.05); g.gain.exponentialRampToValueAtTime(0.0001, t + 1.1);
      o.connect(g).connect(ac.destination); o.start(t); o.stop(t + 1.2);
    });
  } catch {}
}
let last = 0;
export function hype(subtitle = "", force = false) {
  const now = Date.now(); if (!force && now - last < 6000) return; last = now;
  const h = $("#hype"); $("#hwho").textContent = subtitle;
  h.classList.remove("on"); void h.offsetWidth; h.classList.add("on");
  horn();
  if (sound && window.speechSynthesis) setTimeout(() => {
    speechSynthesis.cancel();
    const u = new SpeechSynthesisUtterance("He could go all the way!"); u.rate = 1.15; u.pitch = 0.8; speechSynthesis.speak(u);
  }, 250);
  setTimeout(() => h.classList.remove("on"), 2600);
}
export const unlockAudio = () => { try { ac = ac || new (window.AudioContext || window.webkitAudioContext)(); ac.resume(); } catch {} };

export async function copy(text, btn) {
  try { await navigator.clipboard.writeText(text); const o = btn.textContent; btn.textContent = "Copied ✓"; setTimeout(() => (btn.textContent = o), 1500); }
  catch { window.prompt("Copy this link:", text); }
}
