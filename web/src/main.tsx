import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.tsx'
import { LegalPage, pageKindFromPath } from './LegalPages.tsx'

const legal = pageKindFromPath(window.location.pathname)

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    {legal ? <LegalPage kind={legal} /> : <App />}
  </StrictMode>,
)
