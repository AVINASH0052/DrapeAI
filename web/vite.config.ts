import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      // Local landing → FastAPI so the waitlist form works without CORS setup.
      '/waitlist': {
        target: 'http://127.0.0.1:8000',
        changeOrigin: true,
      },
    },
  },
})
