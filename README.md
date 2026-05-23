# Madeena Care Project (Klinik System)

Proyek aplikasi Flutter yang terintegrasi dengan Firebase & Cloud Firestore.

## 🚀 Panduan Cara Setup Setelah Clone (Mengatasi Eror Firebase)

Karena alasan keamanan, file kredensial dan konfigurasi Firebase (`google-services.json`, `firebase_options.dart`, dll) **tidak dimasukkan** ke dalam repositori GitHub ini. 

Agar aplikasi bisa berjalan langsung tanpa eror setelah di-clone, ikuti langkah-langkah konfigurasi ulang berikut:

### 1. Prasyarat
* Pastikan komputer Anda sudah terinstal [Firebase CLI](https://firebase.google.com/docs/cli).
* Buka terminal komputer Anda dan pastikan sudah login ke akun Firebase:
```bash
  firebase login