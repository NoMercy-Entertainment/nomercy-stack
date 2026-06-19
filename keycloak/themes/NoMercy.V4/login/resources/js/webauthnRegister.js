// Passkey registration ceremony using the native WebAuthn JSON serialization
// (PublicKeyCredential.parseCreationOptionsFromJSON / credential.toJSON).
// Replaces the stock jQuery + base64url.js version, both of which 404 on our theme
// (Keycloak 26 dropped the node_modules/jquery path and we don't ship base64url.js).

export async function registerByWebAuthn(input) {
    const error = document.getElementById("error");
    if (!window.PublicKeyCredential) {
        error.value = input.errmsg;
        document.getElementById("register").requestSubmit();
        return;
    }
    try {
        const options = {
            challenge: input.challenge,
            rp: { name: input.rpEntityName, id: input.rpId },
            user: { id: input.userid, name: input.username, displayName: input.username },
            pubKeyCredParams: input.signatureAlgorithms.map((alg) => ({ type: "public-key", alg })),
        };
        if (input.attestationConveyancePreference !== "not specified") {
            options.attestation = input.attestationConveyancePreference;
        }
        const selection = {};
        if (input.authenticatorAttachment !== "not specified") selection.authenticatorAttachment = input.authenticatorAttachment;
        if (input.requireResidentKey !== "not specified") selection.requireResidentKey = input.requireResidentKey === "Yes";
        if (input.userVerificationRequirement !== "not specified") selection.userVerification = input.userVerificationRequirement;
        if (Object.keys(selection).length) options.authenticatorSelection = selection;
        if (input.createTimeout !== 0) options.timeout = input.createTimeout * 1000;
        if (input.excludeCredentialIds) {
            options.excludeCredentials = input.excludeCredentialIds
                .split(",")
                .map((id) => ({ type: "public-key", id }));
        }

        const publicKey = PublicKeyCredential.parseCreationOptionsFromJSON(options);
        const credential = await navigator.credentials.create({ publicKey });
        const json = credential.toJSON();

        document.getElementById("clientDataJSON").value = json.response.clientDataJSON;
        document.getElementById("attestationObject").value = json.response.attestationObject;
        document.getElementById("publicKeyCredentialId").value = json.id;
        if (json.response.transports) {
            document.getElementById("transports").value = json.response.transports.join(",");
        }
        document.getElementById("authenticatorLabel").value = input.label;
        document.getElementById("register").requestSubmit();
    } catch (caught) {
        error.value = caught;
        document.getElementById("register").requestSubmit();
    }
}
