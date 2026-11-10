(function() {
    var overlay;
    var message;
    var unlockButton;

    function createOverlay() {
        var style = document.createElement('style');
        style.textContent = [
            '#biometric-lock { position: fixed; inset: 0; z-index: 100000; display: flex; align-items: center; justify-content: center; padding: 24px; background: rgba(8, 10, 16, .88); backdrop-filter: blur(24px); -webkit-backdrop-filter: blur(24px); }',
            '#biometric-lock .biometric-lock-card { width: min(100%, 360px); padding: 30px 24px; border: 1px solid rgba(255,255,255,.12); border-radius: 24px; background: rgba(22,25,34,.96); color: #fff; text-align: center; box-shadow: 0 20px 70px rgba(0,0,0,.45); }',
            '#biometric-lock .biometric-lock-icon { width: 72px; height: 72px; margin: 0 auto 18px; border-radius: 22px; display: flex; align-items: center; justify-content: center; color: #4aa2fc; background: rgba(74,162,252,.14); }',
            '#biometric-lock h2 { margin: 0 0 10px; font-size: 23px; }',
            '#biometric-lock p { margin: 0; color: #a7adbb; line-height: 1.45; font-size: 14px; }',
            '#biometric-lock button { width: 100%; margin-top: 22px; padding: 14px 18px; border: 0; border-radius: 14px; background: #3b82f6; color: #fff; font-size: 16px; font-weight: 600; cursor: pointer; }',
            '#biometric-lock button:disabled { opacity: .6; cursor: wait; }',
            '#biometric-lock .biometric-lock-error { min-height: 20px; margin-top: 12px; color: #f87171; font-size: 13px; }',
            '#biometric-lock .biometric-lock-logout { display: inline-block; margin-top: 16px; color: #a7adbb; font-size: 13px; text-decoration: none; }',
            'body.light-mode #biometric-lock { background: rgba(245,247,251,.9); }',
            'body.light-mode #biometric-lock .biometric-lock-card { background: rgba(255,255,255,.97); color: #111; border-color: rgba(0,0,0,.1); }',
            'body.light-mode #biometric-lock p, body.light-mode #biometric-lock .biometric-lock-logout { color: #667085; }'
        ].join('');
        document.head.appendChild(style);

        overlay = document.createElement('div');
        overlay.id = 'biometric-lock';
        overlay.innerHTML = [
            '<div class="biometric-lock-card">',
            '<div class="biometric-lock-icon"><svg width="42" height="42" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round">',
            '<path d="M12 3a7 7 0 0 1 7 7"/><path d="M5 10a7 7 0 0 1 7-7"/><path d="M4 14a8 8 0 0 1 16 0"/><path d="M7 17a5 5 0 0 1 10 0"/><path d="M10 20a2 2 0 0 1 4 0"/>',
            '</svg></div>',
            '<h2>Odblokuj aplikację</h2>',
            '<p>Potwierdź swoją tożsamość za pomocą Face ID, Touch ID lub odcisku palca.</p>',
            '<button type="button" id="biometricUnlockButton">Odblokuj biometrycznie</button>',
            '<div class="biometric-lock-error" id="biometricLockError"></div>',
            '<a class="biometric-lock-logout" href="id.html">Zaloguj się hasłem</a>',
            '</div>'
        ].join('');
        document.body.appendChild(overlay);
        message = document.getElementById('biometricLockError');
        unlockButton = document.getElementById('biometricUnlockButton');
        unlockButton.addEventListener('click', unlock);
    }

    async function unlock() {
        unlockButton.disabled = true;
        message.textContent = '';
        try {
            await window.biometricAuth.authenticate();
            overlay.remove();
        } catch (error) {
            message.textContent = error && error.message ? error.message : 'Nie udało się odblokować aplikacji.';
        } finally {
            if (unlockButton) unlockButton.disabled = false;
        }
    }

    function initialize() {
        if (!window.biometricAuth || !window.biometricAuth.isEnabled()) return;
        createOverlay();
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initialize);
    } else {
        initialize();
    }
})();
