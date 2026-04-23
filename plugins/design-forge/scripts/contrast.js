#!/usr/bin/env node
/**
 * contrast.js — WCAG 2.x Luminance + Contrast + APCA Lc calculator.
 *
 * Usage:
 *   node contrast.js <fg> <bg>
 *
 * Inputs accept:
 *   - Hex: "#ff0000", "#F00", "ff0000"
 *   - RGB: "rgb(255, 0, 0)"
 *   - HSL: "hsl(0, 100%, 50%)" (best-effort parse)
 *
 * Output: JSON to stdout with fields:
 *   {
 *     fg, bg, fg_rgb, bg_rgb,
 *     luminance_fg, luminance_bg,
 *     wcag_ratio,
 *     wcag_aa_normal, wcag_aa_large, wcag_aa_ui,
 *     wcag_aaa_normal, wcag_aaa_large,
 *     apca_lc
 *   }
 *
 * Exit-Code: 0 on success, 1 on parse error.
 */

'use strict';

function parseColor(input) {
  const s = String(input).trim();

  // Hex
  let m = s.match(/^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/);
  if (m) {
    let hex = m[1];
    if (hex.length === 3) hex = hex.split('').map(c => c + c).join('');
    return [
      parseInt(hex.slice(0, 2), 16),
      parseInt(hex.slice(2, 4), 16),
      parseInt(hex.slice(4, 6), 16)
    ];
  }

  // rgb(r, g, b) or rgba(r, g, b, a)
  m = s.match(/rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/i);
  if (m) return [parseInt(m[1]), parseInt(m[2]), parseInt(m[3])];

  // hsl(h, s%, l%) — convert to rgb
  m = s.match(/hsla?\(\s*([\d.]+)\s*,\s*([\d.]+)%\s*,\s*([\d.]+)%/i);
  if (m) {
    const h = parseFloat(m[1]) / 360;
    const sat = parseFloat(m[2]) / 100;
    const l = parseFloat(m[3]) / 100;
    const hslToRgb = (h, s, l) => {
      if (s === 0) return [l * 255, l * 255, l * 255];
      const hue2rgb = (p, q, t) => {
        if (t < 0) t += 1;
        if (t > 1) t -= 1;
        if (t < 1/6) return p + (q - p) * 6 * t;
        if (t < 1/2) return q;
        if (t < 2/3) return p + (q - p) * (2/3 - t) * 6;
        return p;
      };
      const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
      const p = 2 * l - q;
      return [
        Math.round(hue2rgb(p, q, h + 1/3) * 255),
        Math.round(hue2rgb(p, q, h) * 255),
        Math.round(hue2rgb(p, q, h - 1/3) * 255)
      ];
    };
    return hslToRgb(h, sat, l);
  }

  throw new Error(`Cannot parse color: "${input}"`);
}

function relativeLuminance([r, g, b]) {
  const linearize = c => {
    const s = c / 255;
    return s <= 0.03928 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
  };
  const R = linearize(r);
  const G = linearize(g);
  const B = linearize(b);
  return 0.2126 * R + 0.7152 * G + 0.0722 * B;
}

function wcagContrast(fgRgb, bgRgb) {
  const L1 = relativeLuminance(fgRgb);
  const L2 = relativeLuminance(bgRgb);
  const [lighter, darker] = L1 > L2 ? [L1, L2] : [L2, L1];
  return (lighter + 0.05) / (darker + 0.05);
}

/**
 * APCA Lc — simplified approximation for design-forge use.
 * Full APCA spec is more complex; this implements the core polarity-aware Lc.
 * For production-critical APCA use apca-w3 npm library.
 */
function apcaLc(fgRgb, bgRgb) {
  const sRGBtoY = rgb => {
    const R = Math.pow(rgb[0] / 255, 2.4);
    const G = Math.pow(rgb[1] / 255, 2.4);
    const B = Math.pow(rgb[2] / 255, 2.4);
    return 0.2126729 * R + 0.7151522 * G + 0.0721750 * B;
  };
  const txtY = sRGBtoY(fgRgb);
  const bgY = sRGBtoY(bgRgb);
  const normBG = 0.55;
  const normTXT = 0.58;
  const revTXT = 0.57;
  const revBG = 0.62;
  const blkThrs = 0.022;
  const blkClmp = 1.414;
  const scaleBoW = 1.14;
  const scaleWoB = 1.14;

  const clampY = y => y > blkThrs ? y : y + Math.pow(blkThrs - y, blkClmp);
  const txtClamp = clampY(txtY);
  const bgClamp = clampY(bgY);

  let sapc = 0;
  if (bgClamp > txtClamp) {
    // Normal polarity: dark text on light bg
    sapc = (Math.pow(bgClamp, normBG) - Math.pow(txtClamp, normTXT)) * scaleBoW;
  } else {
    // Reverse polarity: light text on dark bg
    sapc = (Math.pow(bgClamp, revBG) - Math.pow(txtClamp, revTXT)) * scaleWoB;
  }

  const Lc = sapc * 100;
  return Math.abs(Lc) < 7.5 ? 0 : Lc;
}

function main() {
  const args = process.argv.slice(2);
  if (args.length !== 2) {
    console.error('Usage: node contrast.js <fg> <bg>');
    process.exit(1);
  }

  try {
    const fgRgb = parseColor(args[0]);
    const bgRgb = parseColor(args[1]);
    const lum_fg = relativeLuminance(fgRgb);
    const lum_bg = relativeLuminance(bgRgb);
    const ratio = wcagContrast(fgRgb, bgRgb);
    const lc = apcaLc(fgRgb, bgRgb);

    const result = {
      fg: args[0],
      bg: args[1],
      fg_rgb: fgRgb,
      bg_rgb: bgRgb,
      luminance_fg: Number(lum_fg.toFixed(4)),
      luminance_bg: Number(lum_bg.toFixed(4)),
      wcag_ratio: Number(ratio.toFixed(2)),
      wcag_aa_normal: ratio >= 4.5,
      wcag_aa_large: ratio >= 3.0,
      wcag_aa_ui: ratio >= 3.0,
      wcag_aaa_normal: ratio >= 7.0,
      wcag_aaa_large: ratio >= 4.5,
      apca_lc: Number(lc.toFixed(1)),
      apca_body_pass: Math.abs(lc) >= 75,
      apca_max_safe: Math.abs(lc) <= 90
    };
    console.log(JSON.stringify(result, null, 2));
    process.exit(0);
  } catch (err) {
    console.error(JSON.stringify({ error: err.message }));
    process.exit(1);
  }
}

main();
