/** @type {import('tailwindcss').Config} */
// Colours are CSS variables (RGB triplets) so the light "lab notebook" theme and
// the dark theme share every utility class. See src/index.css.
const v = (name) => `rgb(var(--c-${name}) / <alpha-value>)`;

export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        base: v('base'),
        panel: v('panel'),
        panel2: v('panel2'),
        line: v('line'),
        line2: v('line2'),
        fg: v('fg'),
        muted: v('muted'),
        faint: v('faint'),
        accent: v('accent'),
        maroon: v('maroon'),
        ok: v('ok'),
        warn: v('warn'),
        crit: v('crit'),
        idle: v('idle'),
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        serif: ['"Source Serif 4"', 'Georgia', 'serif'],
        mono: ['"IBM Plex Mono"', 'ui-monospace', 'monospace'],
      },
      fontSize: {
        '2xs': ['0.6875rem', { lineHeight: '1rem' }],
      },
      borderRadius: {
        DEFAULT: '4px',
      },
    },
  },
  plugins: [],
};
