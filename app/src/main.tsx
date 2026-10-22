import { createRoot } from 'react-dom/client'
import App from './App'
import './index.css'
import { AppProvider } from './store'
import { daftarkanSW, pasangListenerInstall } from './lib/pwa'

// Dipasang sebelum React render supaya event `beforeinstallprompt`
// nggak kelewat (event ini bisa datang sangat awal).
pasangListenerInstall()
daftarkanSW()

const el = document.getElementById('root')
if (!el) throw new Error('Root element tidak ditemukan')

createRoot(el).render(
  <AppProvider>
    <App />
  </AppProvider>
)
