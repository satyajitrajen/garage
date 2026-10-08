import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// In production the Go server serves this build at / and the API at /api
// (same origin). In development, `npm run dev` proxies /api to the local
// Go server on :8080.
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5174,
    proxy: { '/api': 'http://localhost:8080' },
  },
})
