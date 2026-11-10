(function() {
    var toggle = document.getElementById('biometricToggle');
    var status = document.getElementById('biometricStatus');
    var message = document.getElementById('biometricMessage');
    if (!toggle || !status || !message) return;

    function render() {
        var enabled = window.biometricAuth.isEnabled();
        toggle.classList.toggle('active', enabled);
        toggle.setAttribute('aria-pressed', String(enabled));
        toggle.setAttribute('aria-label', enabled ? 'Wyłącz logowanie biometryczne' : 'Włącz logowanie biometryczne');
        status.textContent = enabled ? 'Włączone' : 'Wyłączone';
    }

    function showError(error) {
        message.textContent = error && error.message ? error.message : 'Nie udało się zmienić ustawienia.';
    }

    render();
    toggle.addEventListener('click', async function() {
        message.textContent = '';
        if (window.biometricAuth.isEnabled()) {
            window.biometricAuth.disable();
            render();
            return;
        }

        toggle.disabled = true;
        try {
            await window.biometricAuth.register();
            render();
        } catch (error) {
            showError(error);
        } finally {
            toggle.disabled = false;
        }
    });
})();
