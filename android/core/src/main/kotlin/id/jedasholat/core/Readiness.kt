package id.jedasholat.core

/**
 * Ordered setup checklist for enforcement. The first unfinished step is the only thing the
 * UI needs to ask for, so a user never sees "protection is on" while zero apps are selected.
 */
enum class ReadinessStep { PROTECTION, APPS, CONSENT, ACCESSIBILITY, SERVICE, READY }

data class ReadinessStepInfo(
    val step: ReadinessStep,
    val done: Boolean,
    val title: String,
    val detail: String,
    val action: String,
)

data class Readiness(
    val steps: List<ReadinessStepInfo>,
    val next: ReadinessStep,
) {
    val ready: Boolean get() = next == ReadinessStep.READY
    val nextInfo: ReadinessStepInfo get() = steps.first { it.step == next }
    val remaining: Int get() = steps.count { !it.done }
}

object ReadinessGuide {
    /**
     * [capabilities.accessibilityBound] is the real service connection state, not just the
     * settings toggle, because an enabled-but-unbound service never shows the overlay.
     */
    fun assess(settings: Settings, capabilities: Capabilities): Readiness = assess(
        protectionEnabled = settings.protectionEnabled,
        selectedCount = settings.selectedPackages.size,
        accessibilityConsent = settings.accessibilityConsent,
        accessibilityEnabled = capabilities.accessibility,
        serviceBound = capabilities.accessibilityBound,
    )

    /** Primitive overload so diagnostics can describe state without fabricating a settings object. */
    fun assess(
        protectionEnabled: Boolean,
        selectedCount: Int,
        accessibilityConsent: Boolean,
        accessibilityEnabled: Boolean,
        serviceBound: Boolean,
    ): Readiness {
        val steps = listOf(
            ReadinessStepInfo(
                ReadinessStep.PROTECTION, protectionEnabled,
                "Perlindungan masih mati",
                "Jadwal tetap tersimpan. Nyalakan perlindungan saat kamu siap menjeda aplikasi.",
                "Nyalakan perlindungan",
            ),
            ReadinessStepInfo(
                ReadinessStep.APPS, selectedCount > 0,
                "Belum ada aplikasi dipilih",
                "Tidak ada aplikasi yang dipilih otomatis, jadi belum ada yang dijeda. Telepon, Pengaturan, dan akses darurat tetap aman.",
                "Pilih aplikasi",
            ),
            ReadinessStepInfo(
                ReadinessStep.CONSENT, accessibilityConsent,
                "Persetujuan layar jeda",
                "Layar jeda butuh Layanan Aksesibilitas. JedaSholat hanya membaca nama paket aplikasi yang terbuka, bukan isi layar atau ketikan.",
                "Baca & setujui",
            ),
            ReadinessStepInfo(
                ReadinessStep.ACCESSIBILITY, accessibilityEnabled,
                "Izin aksesibilitas belum aktif",
                "Aktifkan JedaSholat di Pengaturan Android → Aksesibilitas, lalu kembali ke aplikasi ini.",
                "Buka Aksesibilitas",
            ),
            ReadinessStepInfo(
                ReadinessStep.SERVICE, serviceBound,
                "Layanan belum tersambung",
                "Izin tercatat aktif, tetapi layanan belum tersambung. Matikan lalu nyalakan lagi izin JedaSholat di Aksesibilitas Android.",
                "Buka Aksesibilitas",
            ),
            ReadinessStepInfo(
                ReadinessStep.READY, true,
                "Perlindungan siap",
                "Hanya aplikasi pilihanmu yang dijeda saat jendela sholat aktif. Di luar itu semua tetap bebas.",
                "",
            ),
        )
        val next = steps.firstOrNull { !it.done }?.step ?: ReadinessStep.READY
        return Readiness(steps, next)
    }
}
