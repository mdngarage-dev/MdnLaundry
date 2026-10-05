# Struktur folder `lib/`

```
lib/
├── main.dart
├── core/                         # dipakai semua fitur
│   ├── app_exports.dart          # barrel (dulu: screens/main_screens.dart)
│   ├── config/                   # app_config (AppConfig, OutletSettings), firebase_config (web)
│   ├── theme/                    # theme.dart, theme_provider.dart
│   ├── utils/                    # input_formatters, permissions, format_utils (formatRupiah)
│   └── widgets/                  # navbar, button_bawah, global_refresh, date_range_picker_widget
├── models/                       # data class murni
│   ├── layanan.dart
│   └── notif_item.dart
├── services/                     # akses Firebase / printer / notifikasi / settings
│   ├── order_payment_service.dart        # bayar sebagian + sinkron order<->keuangan
│   ├── outlet_service.dart, outlet_settings_service.dart
│   ├── printer_settings_service.dart, wa_settings_service.dart
│   ├── notif_storage.dart, notif_laundry_service.dart
│   ├── payment_service.dart, subscription_service.dart
│   ├── thermal_printer_service.dart   # jalur cetak (teks + gambar, ada fallback)
│   └── receipt_image_builder.dart     # menggambar struk customer jadi bitmap
└── features/
    ├── auth/          getstarted, signin, signup, email_verification, auth_wrapper
    ├── home/          home_wrapper, home_screen, notifikasi
    ├── order/
    │   ├── add_order.dart, order_list.dart, order_detail.dart, scanner_screen.dart
    │   └── widgets/
    │       ├── add/      layanan_picker_sheet, item_detail_sheet
    │       └── detail/   pilih_rak_dialog, edit_item_list_sheet, layanan_picker_sheet,
    │                     item_detail_sheet, bayar_sheet
    ├── laporan/       harian, order, ringkasan, pelanggan, pegawai, pengeluaran
    ├── outlet/        outlet_management, outlet_selector
    ├── printer/       print_screen, printer_dialog
    ├── profile/       profile_screen
    ├── settings/      main_setting, outlet_setting, akun_keamanan, ... + outlet/*
    ├── subscription/  subscription_dashboard, payment_page
    └── developer/     developer_dashboard, tabs/, detail/
```

Aturan singkat:
- Kelas data -> `models/`, akses Firestore/prefs -> `services/`, layar -> `features/<fitur>/`.
- Widget (sheet/dialog) yang hanya dipakai satu layar -> `features/<fitur>/widgets/`.
- Format rupiah: pakai `formatRupiah()` dari `core/utils/format_utils.dart` (jangan bikin `_formatRupiah` baru).
