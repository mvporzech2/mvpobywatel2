(function() {
    function toBase64Url(bytes) {
        var binary = '';
        bytes.forEach(function(byte) { binary += String.fromCharCode(byte); });
        return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
    }

    function fromBase64Url(value) {
        var base64 = value.replace(/-/g, '+').replace(/_/g, '/');
        while (base64.length % 4) base64 += '=';
        var binary = atob(base64);
        return Uint8Array.from(binary, function(char) { return char.charCodeAt(0); });
    }

    function randomBytes(length) {
        var bytes = new Uint8Array(length);
        crypto.getRandomValues(bytes);
        return bytes;
    }

    window.biometricAuth = {
        isSupported: function() {
            return Boolean(window.PublicKeyCredential && navigator.credentials);
        },
        getCredentialId: function() {
            return localStorage.getItem('mobywatel_biometric_credential');
        },
        isEnabled: function() {
            return localStorage.getItem('mobywatel_biometric_enabled') === 'true' &&
                Boolean(this.getCredentialId());
        },
        register: async function() {
            if (!this.isSupported()) throw new Error('Ta przeglądarka nie obsługuje logowania biometrycznego.');
            if (!window.isSecureContext) throw new Error('Logowanie biometryczne wymaga bezpiecznego połączenia HTTPS.');

            var userPassword = localStorage.getItem('user_password');
            if (!userPassword) throw new Error('Najpierw zaloguj się hasłem.');

            var credential = await navigator.credentials.create({
                publicKey: {
                    challenge: randomBytes(32),
                    rp: { name: 'mObywatel', id: location.hostname },
                    user: {
                        id: randomBytes(16),
                        name: 'mObywatel',
                        displayName: 'Konto mObywatel'
                    },
                    pubKeyCredParams: [
                        { type: 'public-key', alg: -7 },
                        { type: 'public-key', alg: -257 }
                    ],
                    authenticatorSelection: {
                        residentKey: 'preferred',
                        userVerification: 'required'
                    },
                    timeout: 60000,
                    attestation: 'none'
                }
            });

            if (!credential) throw new Error('Nie udało się zarejestrować biometrii.');
            localStorage.setItem('mobywatel_biometric_credential', toBase64Url(new Uint8Array(credential.rawId)));
            localStorage.setItem('mobywatel_biometric_enabled', 'true');
        },
        authenticate: async function() {
            if (!this.isSupported()) throw new Error('Ta przeglądarka nie obsługuje logowania biometrycznego.');
            var credentialId = this.getCredentialId();
            if (!credentialId) throw new Error('Logowanie biometryczne nie jest skonfigurowane.');

            var credential = await navigator.credentials.get({
                publicKey: {
                    challenge: randomBytes(32),
                    rpId: location.hostname,
                    allowCredentials: [{
                        type: 'public-key',
                        id: fromBase64Url(credentialId)
                    }],
                    userVerification: 'required',
                    timeout: 60000
                }
            });

            if (!credential) throw new Error('Nie udało się potwierdzić tożsamości.');
            return true;
        },
        disable: function() {
            localStorage.removeItem('mobywatel_biometric_enabled');
            localStorage.removeItem('mobywatel_biometric_credential');
        }
    };
})();
