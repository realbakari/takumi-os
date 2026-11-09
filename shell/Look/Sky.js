.pragma library
// The Sky: procedural landscapes painted from each theme's full palette, name, and clock phase.
// When a theme does not ship a static wallpaper in skies/, each theme gets its own deterministic
// horizon motif so no two themes look identical.
// Keep preview/index.html drawSky synced with this painter.

function hex(h) { return [1, 3, 5].map(function (i) { return parseInt(h.slice(i, i + 2), 16); }); }
function luma(h) {
    var c = hex(h);
    return (0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]) / 255;
}
function mix(a, b, t) {
    var A = hex(a), B = hex(b);
    return "#" + A.map(function (v, i) { var c = Math.round(v + (B[i] - v) * t); return (c < 16 ? "0" : "") + Math.max(0, Math.min(255, c)).toString(16); }).join("");
}
function rgba(h, a) { var c = hex(h); return "rgba(" + c[0] + "," + c[1] + "," + c[2] + "," + a + ")"; }
function hashStr(s) {
    var h = 2166136261 >>> 0;
    s = String(s || "ion");
    for (var i = 0; i < s.length; i++) {
        h ^= s.charCodeAt(i);
        h = Math.imul(h, 16777619) >>> 0;
    }
    return h || 7;
}
function rng(seed) {
    return function () {
        seed |= 0; seed = seed + 0x6D2B79F5 | 0;
        var t = Math.imul(seed ^ seed >>> 15, 1 | seed);
        t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
        return ((t ^ t >>> 14) >>> 0) / 4294967296;
    };
}

// p: { accent, background, surface, foreground, muted?, cyan?, blue?, magenta?, yellow?, green?, red? }.
function paint(ctx, W, H, p, phase, t, name) {
    var VW = 1600, VH = 1000, night = phase === "night";
    var light = luma(p.background) > 0.45;
    var seed = hashStr(name || "ion");
    var r = rng(seed);
    var archetype = seed % 6;
    var HZ = 665 + Math.round((r() - 0.5) * 65);
    var secPool = [p.cyan || p.accent, p.blue || p.accent, p.magenta || p.accent, p.yellow || p.accent, p.green || p.accent];
    var secondary = secPool[seed % secPool.length];
    var tertiary = secPool[(seed + 2) % secPool.length];

    var s = Math.max(W / VW, H / VH);
    ctx.reset();
    ctx.save();
    ctx.translate((W - VW * s) / 2, (H - VH * s) / 2);
    ctx.scale(s, s);

    var glow = light
        ? ({ dawn: 0.22, day: 0.10, dusk: 0.24, night: 0.14 }[phase] || 0.12)
        : ({ dawn: 0.34, day: 0.16, dusk: 0.38, night: 0.10 }[phase] || 0.16);
    var topMix = mix(p.background, p.surface, light ? 0.65 : 0.7);
    var top = mix(topMix, secondary, light ? 0.08 : 0.14);
    var mid = mix(p.surface, tertiary, light ? 0.06 : 0.10);
    var hz = mix(p.background, p.accent, glow);
    var seaTop = mix(p.background, secondary, light ? 0.08 : 0.10);
    var seaBot = mix(p.background, p.surface, light ? 0.42 : 0.55);

    var sky = ctx.createLinearGradient(0, 0, 0, VH);
    sky.addColorStop(0, top);
    sky.addColorStop(HZ / VH * 0.52, mid);
    sky.addColorStop(HZ / VH, hz);
    sky.addColorStop(HZ / VH + 0.0005, seaTop);
    sky.addColorStop(1, seaBot);
    ctx.fillStyle = sky;
    ctx.fillRect(0, 0, VW, VH);

    var i, k;
    if (night && !light) {
        ctx.fillStyle = p.foreground;
        var starCount = 85 + (seed % 55);
        for (i = 0; i < starCount; i++) {
            var sx0 = r() * VW, sy0 = r() * HZ * 0.9, a = 0.14 + r() * 0.55, rad = 0.6 + r() * 1.25;
            ctx.globalAlpha = a; ctx.beginPath(); ctx.arc(sx0, sy0, rad, 0, Math.PI * 2); ctx.fill();
        }
        ctx.globalAlpha = 1;
        aurora(ctx, p.accent, 110 + (seed % 60), 42, 0.13, seed + 3);
        aurora(ctx, secondary, 185 + (seed % 50), -36, 0.08, seed + 5);
    }

    // Horizon atmospheric bloom
    var glowA = light ? 0.14 : ({ dawn: 0.22, day: 0.11, dusk: 0.25, night: 0.16 }[phase] || 0.14);
    var bandH = 220;
    var bloom = ctx.createLinearGradient(0, HZ - bandH, 0, HZ);
    bloom.addColorStop(0, rgba(p.accent, 0));
    bloom.addColorStop(0.6, rgba(secondary, glowA * 0.55));
    bloom.addColorStop(1, rgba(p.accent, glowA));
    ctx.fillStyle = bloom;
    ctx.fillRect(0, HZ - bandH, VW, bandH);

    // Disc / eclipse celestial element
    var R = night ? 48 : 88;
    var sx = 220 + t * 1160;
    var sy = HZ - Math.sin(Math.PI * t) * (night ? 500 : 450) + (night ? 0 : 24);
    var haloR = R * (night ? 3.1 : phase === "day" ? 2.5 : 3.5);
    var haloA = light ? 0.22 : ({ dawn: 0.36, day: 0.19, dusk: 0.38, night: 0.25 }[phase] || 0.2);

    ctx.save();
    ctx.beginPath(); ctx.rect(0, 0, VW, HZ); ctx.clip();
    if (archetype === 2 && !night) {
        // Orbital rings around the celestial body
        ctx.strokeStyle = rgba(secondary, light ? 0.22 : 0.28);
        ctx.lineWidth = 1.6;
        ctx.beginPath(); ctx.ellipse(sx, sy, R * 2.2, R * 0.52, -0.22, 0, Math.PI * 2); ctx.stroke();
        ctx.strokeStyle = rgba(p.accent, light ? 0.16 : 0.2);
        ctx.lineWidth = 1.1;
        ctx.beginPath(); ctx.ellipse(sx, sy, R * 3.1, R * 0.78, -0.22, 0, Math.PI * 2); ctx.stroke();
    }
    ctx.globalAlpha = phase === "day" ? (light ? 0.85 : 0.92) : 1;
    ctx.fillStyle = p.accent;
    ctx.beginPath(); ctx.arc(sx, sy, R, 0, Math.PI * 2); ctx.fill();
    ctx.globalAlpha = 1;
    if (night) {
        ctx.fillStyle = sky;
        ctx.beginPath(); ctx.arc(sx + R * 0.42, sy - R * 0.22, R * 0.92, 0, Math.PI * 2); ctx.fill();
    } else if (seed % 4 === 0) {
        // Subtle annular eclipse ring silhouette
        ctx.fillStyle = mix(p.background, p.surface, 0.45);
        ctx.globalAlpha = light ? 0.22 : 0.72;
        ctx.beginPath(); ctx.arc(sx - R * 0.08, sy + R * 0.06, R * 0.84, 0, Math.PI * 2); ctx.fill();
        ctx.globalAlpha = 1;
    }
    var halo = ctx.createRadialGradient(sx, sy, R * 0.55, sx, sy, haloR);
    halo.addColorStop(0, rgba(p.accent, haloA));
    halo.addColorStop(0.5, rgba(secondary, haloA * 0.35));
    halo.addColorStop(1, rgba(p.accent, 0));
    ctx.fillStyle = halo;
    ctx.fillRect(sx - haloR, sy - haloR, haloR * 2, haloR * 2);
    ctx.restore();

    // Distinct archetype foreground & midground layers with legible tonal separation
    var far = light ? mix(hz, p.foreground, 0.12) : mix(hz, p.foreground, 0.11);
    var midTone = light ? mix(p.background, p.foreground, 0.19) : mix(p.surface, p.foreground, 0.16);
    var near = light ? mix(p.background, p.foreground, 0.28) : mix(p.background, p.surface, 0.65);
    var rimCol = mix(p.accent, p.foreground, light ? 0.18 : 0.32);

    if (archetype === 0) {
        // Architectural Monoliths & Skybridge
        monoliths(ctx, VW, HZ, r, p, far, near, night, secondary);
        waterSurface(ctx, VW, VH, HZ, p, r, sx, sy, R, night, light, secondary);
    } else if (archetype === 1) {
        // Layered Alpine Mountain Ridges & Lake
        ridge(ctx, VW, HZ, r, 165, 22, far, rgba(secondary, light ? 0.18 : 0.22));
        ridge(ctx, VW, HZ, r, 110, 16, midTone, rgba(p.accent, light ? 0.22 : 0.28));
        ridge(ctx, VW, HZ, r, 58, 12, near, rgba(rimCol, 0.30));
        waterSurface(ctx, VW, VH, HZ, p, r, sx, sy, R, night, light, secondary);
    } else if (archetype === 2) {
        // Orbital Horizon & Topographic Wave Plane
        ridge(ctx, VW, HZ, r, 72, 18, far, rgba(secondary, 0.22));
        ctx.fillStyle = p.foreground; ctx.globalAlpha = light ? 0.18 : 0.22; ctx.fillRect(0, HZ, VW, 1.4);
        ctx.globalAlpha = 1;
        for (k = 1; k <= 18; k++) {
            var u = k / 18, cy = HZ + (VH - HZ) * Math.pow(u, 1.55);
            ctx.strokeStyle = k % 3 === 0 ? rgba(p.accent, 0.20 + u * 0.18) : rgba(p.foreground, 0.06 + u * 0.08);
            ctx.lineWidth = 0.8 + u * 1.4;
            ctx.beginPath();
            for (var px = 0; px <= VW; px += 40) {
                var wave = Math.sin(px * 0.005 + k * 0.45 + seed) * (6 + u * 18);
                if (px === 0) ctx.moveTo(px, cy + wave); else ctx.lineTo(px, cy + wave);
            }
            ctx.stroke();
        }
    } else if (archetype === 3) {
        // Coastal Islands & Quiet Piers
        ridge(ctx, VW, HZ, r, 95, 14, far, rgba(secondary, 0.16));
        ctx.fillStyle = near;
        // Left promontory + right island
        ctx.beginPath(); ctx.moveTo(0, HZ); ctx.lineTo(0, HZ - 36); ctx.quadraticCurveTo(210, HZ - 74, 420, HZ); ctx.closePath(); ctx.fill();
        ctx.beginPath(); ctx.moveTo(1140, HZ); ctx.quadraticCurveTo(1360, HZ - 62, 1600, HZ - 28); ctx.lineTo(1600, HZ); ctx.closePath(); ctx.fill();
        // Minimal pier extending into open bay & warm beacon light
        var px0 = 385 + Math.round(r() * 55);
        ctx.fillStyle = mix(near, p.foreground, 0.25);
        ctx.fillRect(px0, HZ - 14, 175, 3);
        for (var m = 0; m < 4; m++) ctx.fillRect(px0 + 28 + m * 42, HZ - 14, 3, 28);
        ctx.fillStyle = p.accent; ctx.beginPath(); ctx.arc(px0 + 168, HZ - 22, 3.6, 0, Math.PI * 2); ctx.fill();
        waterSurface(ctx, VW, VH, HZ, p, r, sx, sy, R, night, light, secondary);
    } else if (archetype === 4) {
        // Asymmetric Bamboo / Reed Mist Grove
        ridge(ctx, VW, HZ, r, 60, 12, far, rgba(secondary, 0.14));
        for (i = 0; i < 22; i++) {
            var side = i % 2 === 0 ? 30 + r() * 390 : VW - 30 - r() * 390;
            var lean = (r() - 0.5) * 60;
            var th = 140 + r() * 330;
            var tw = 3.0 + r() * 7.0;
            var mx = side + lean * 0.45, my = HZ - th * 0.52, tx = side + lean, ty = HZ - th;
            ctx.strokeStyle = i % 3 === 0 ? near : midTone;
            ctx.lineWidth = tw;
            ctx.beginPath(); ctx.moveTo(side, HZ + 4); ctx.quadraticCurveTo(mx, my, tx, ty); ctx.stroke();
            if (tw > 5.5) {
                // Subtle segmented bamboo node highlights
                ctx.strokeStyle = rgba(p.accent, light ? 0.18 : 0.22);
                ctx.lineWidth = 1.1;
                for (var nd = 1; nd <= 3; nd++) {
                    var uN = nd * 0.26, nx = side + lean * uN * 0.9, ny = HZ - th * uN;
                    ctx.beginPath(); ctx.moveTo(nx - tw * 0.6, ny); ctx.lineTo(nx + tw * 0.6, ny); ctx.stroke();
                }
            }
        }
        // Horizontal valley mist ribbons
        for (i = 0; i < 3; i++) {
            var mry = HZ - 45 + i * 26;
            var mg = ctx.createLinearGradient(0, mry - 22, 0, mry + 22);
            mg.addColorStop(0, rgba(p.surface, 0)); mg.addColorStop(0.5, rgba(p.surface, light ? 0.35 : 0.28)); mg.addColorStop(1, rgba(p.surface, 0));
            ctx.fillStyle = mg; ctx.fillRect(0, mry - 22, VW, 44);
        }
        waterSurface(ctx, VW, VH, HZ, p, r, sx, sy, R, night, light, secondary);
    } else {
        // Stratified Sweeping Dunes / Paper Fold Layers
        var bands = 4;
        for (i = 0; i < bands; i++) {
            var u0 = i / (bands - 1);
            var baseY = HZ - 145 + u0 * 235;
            var tilt = (i % 2 === 0 ? -1 : 1) * (24 + r() * 18);
            var hL = baseY + tilt;
            var hR = baseY - tilt * 0.75 + (r() - 0.5) * 18;
            var col = i === 0 ? far : i === 1 ? midTone : mix(p.background, p.surface, 0.36 + u0 * 0.38);
            ctx.fillStyle = col;
            ctx.beginPath(); ctx.moveTo(0, VH); ctx.lineTo(0, hL);
            ctx.bezierCurveTo(VW * 0.34, hL + (tilt < 0 ? -52 : 34),
                              VW * 0.67, hR + (tilt < 0 ? 44 : -48), VW, hR);
            ctx.lineTo(VW, VH); ctx.closePath(); ctx.fill();
            ctx.strokeStyle = rgba(i === 1 ? p.accent : rimCol, light ? 0.26 : 0.30 - u0 * 0.04);
            ctx.lineWidth = 1.5; ctx.stroke();
        }
    }

    // Subtle framing vignette (much softer on light themes so paper themes stay crisp and open)
    var vigA = light ? 0.14 : 0.46;
    var vig = ctx.createRadialGradient(VW / 2, VH * 0.45, VW * 0.34, VW / 2, VH * 0.45, VW * 0.92);
    vig.addColorStop(0, rgba(p.background, 0));
    vig.addColorStop(1, rgba(p.background, vigA));
    ctx.fillStyle = vig; ctx.fillRect(0, 0, VW, VH);
    ctx.restore();
}

function ridge(ctx, VW, HZ, r, peak, segs, fill, rim) {
    ctx.fillStyle = fill;
    ctx.beginPath();
    ctx.moveTo(0, HZ + 2);
    var step = VW / segs, y = HZ - 14 - r() * peak * 0.4;
    ctx.lineTo(0, y);
    for (var i = 1; i <= segs; i++) {
        var x = i * step;
        var flank = 1 - Math.abs(i / segs - 0.5) * 0.55;
        y = HZ - (10 + r() * peak * flank);
        ctx.lineTo(x, y);
    }
    ctx.lineTo(VW, HZ + 2);
    ctx.closePath();
    ctx.fill();
    if (rim) {
        ctx.strokeStyle = rim;
        ctx.lineWidth = 1.2;
        ctx.stroke();
    }
}

function monoliths(ctx, VW, HZ, r, p, far, near, night, secondary) {
    function tower(x, w, h, fill, lit) {
        ctx.fillStyle = fill; ctx.fillRect(x, HZ - h, w, h);
        if (lit && h > 34 && r() < 0.45) {
            var sw = Math.max(3, Math.round(w * (0.45 + r() * 0.25))), sh = 8 + Math.floor(r() * Math.min(30, h * 0.35));
            ctx.fillRect(x + Math.round((w - sw) / 2), HZ - h - sh, sw, sh); h += sh;
        }
        if (lit && h > 50 && r() < 0.24) ctx.fillRect(x + Math.round(w / 2) - 1, HZ - h - 26 - Math.floor(r() * 24), 1.6, 30 + Math.floor(r() * 24));
        if (lit && night && h > 24) {
            for (var j = 0; j < 4; j++) if (r() < 0.36) {
                ctx.fillStyle = j % 2 === 0 ? p.accent : secondary; ctx.globalAlpha = 0.82;
                ctx.fillRect(x + 2 + Math.floor(r() * Math.max(1, w - 5)), HZ - h + 6 + Math.floor(r() * Math.max(1, h - 12)), 2, 3);
                ctx.globalAlpha = 1; ctx.fillStyle = fill;
            }
        }
    }
    function cluster(x0, x1, peak, fill, lit, gapMax) {
        var x = x0;
        while (x < x1) {
            var w = 6 + Math.floor(r() * (lit ? 26 : 36)), u = (x - x0) / (x1 - x0), env = Math.pow(Math.sin(Math.PI * u), 0.8);
            tower(x, w, 6 + Math.floor((r() * 0.65 + 0.35) * peak * env), fill, lit);
            x += w + 2 + Math.floor(r() * gapMax) + (r() < 0.08 ? 18 : 0);
        }
    }
    cluster(0, 620, 80, far, false, 4); cluster(1060, 1600, 62, far, false, 4);
    cluster(30, 540, 165, near, true, 7); cluster(1180, 1570, 108, near, true, 7);
}

function waterSurface(ctx, VW, VH, HZ, p, r, sx, sy, R, night, light, secondary) {
    ctx.fillStyle = p.foreground; ctx.globalAlpha = light ? 0.20 : 0.18; ctx.fillRect(0, HZ, VW, 1.2);
    for (var k = 1; k <= 26; k++) {
        var u2 = k / 26, ly = HZ + (VH - HZ) * Math.pow(u2, 1.7);
        ctx.globalAlpha = (light ? 0.05 : 0.045) + u2 * 0.055; ctx.fillRect(0, ly, VW, 0.7 + u2 * 1.6);
    }
    if (sy < HZ + R) {
        for (k = 0; k < 16; k++) {
            var u3 = k / 16, ry = HZ + 6 + (VH - HZ) * 0.62 * Math.pow(u3, 1.5), rw = R * (night ? 1.15 : 1.75) * (1 - u3 * 0.7) * (0.55 + r() * 0.45);
            ctx.fillStyle = k % 3 === 0 ? secondary : p.accent;
            ctx.globalAlpha = (night ? 0.38 : 0.55) * (1 - u3);
            ctx.fillRect(sx - rw / 2 + (r() - 0.5) * 14, ry, rw, 2 + u3 * 3);
        }
    }
    ctx.globalAlpha = 1;
}

function aurora(ctx, color, y, dy, alpha, seed) {
    var VW = 1600, r = rng(seed), p1 = r() * 6.28, p2 = r() * 6.28;
    ctx.save();
    ctx.globalCompositeOperation = "lighter";
    ctx.lineWidth = 6;
    for (var x = -10; x <= VW + 10; x += 4) {
        var u = Math.min(1, Math.max(0, x / VW));
        var top = y + Math.sin(u * 3.1 + p1) * dy + Math.sin(u * 7.7 + p2) * dy * 0.3;
        var h = 60 + 80 * (0.5 + 0.5 * Math.sin(u * 9.0 + p2)) + r() * 26;
        var env = Math.pow(Math.sin(Math.PI * u), 0.7);
        var a = alpha * env * (0.3 + 0.7 * (0.5 + 0.5 * Math.sin(u * 15.0 + p1))) * (0.75 + r() * 0.25);
        if (a < 0.004) continue;
        var g = ctx.createLinearGradient(0, top, 0, top + h);
        g.addColorStop(0, rgba(color, 0)); g.addColorStop(0.12, rgba(color, a)); g.addColorStop(1, rgba(color, 0));
        ctx.strokeStyle = g;
        ctx.beginPath(); ctx.moveTo(x, top); ctx.lineTo(x, top + h); ctx.stroke();
    }
    ctx.restore();
}

// Where the painted horizon of a theme's sky falls on a W x H screen (paint's first draw sets it).
function horizon(W, H, name) {
    var VW = 1600, VH = 1000, s = Math.max(W / VW, H / VH);
    var HZ = 665 + Math.round((rng(hashStr(name || "ion"))() - 0.5) * 65);
    return (H - VH * s) / 2 + HZ * s;
}

function twinkles(W, H, name) {
    var VW = 1600, VH = 1000, HZ = 665, s = Math.max(W / VW, H / VH), ox = (W - VW * s) / 2, oy = (H - VH * s) / 2;
    var r = rng(hashStr(name || "ion") + 11), out = [];
    for (var i = 0; i < 16; i++) out.push({ x: ox + r() * VW * s, y: oy + (40 + r() * (HZ * 0.7)) * s, size: 1.6 + r() * 1.2, period: 2400 + r() * 3600, delay: r() * 3000 });
    return out;
}

function arc(phase, now, sched, followsClock) {
    if (!followsClock) return { dawn: 0.12, day: 0.5, dusk: 0.86, night: 0.62 }[phase] || 0.5;
    if (phase !== "night") return Math.min(1, Math.max(0, (now - sched.dawn) / (sched.night - sched.dawn)));
    var span = 1440 - sched.night + sched.dawn, into = (now - sched.night + 1440) % 1440;
    return Math.min(1, Math.max(0, into / span));
}
function phaseAt(now, sched) {
    if (now >= sched.night || now < sched.dawn) return "night";
    if (now >= sched.dusk) return "dusk";
    if (now >= sched.day) return "day";
    return "dawn";
}
