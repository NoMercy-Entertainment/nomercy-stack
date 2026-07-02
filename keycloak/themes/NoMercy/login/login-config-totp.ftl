<#import "template.ftl" as layout>
<#import "password-commons.ftl" as passwordCommons>
<@layout.registrationLayout displayRequiredFields=false displayMessage=!messagesPerField.existsError('totp','userLabel'); section>

    <#if section = "header">
        <span class="nm-head">
            <span class="nm-head__title">${msg("loginTotpTitle")}</span>
        </span>
    <#elseif section = "form">
        <div style="display:flex;gap:3rem;">
            <ol id="kc-totp-settings">
                <li>
                    <p>${msg("loginTotpStep1")}</p>

                    <ul id="kc-totp-supported-apps">
                        <#list totp.supportedApplications as app>
                            <li>${msg(app)}</li>
                        </#list>
                    </ul>
                </li>

                <#if mode?? && mode = "manual">
                    <li>
                        <p>${msg("loginTotpManualStep2")}</p>
                        <p><span id="kc-totp-secret-key">${totp.totpSecretEncoded}</span></p>
                        <p><a href="${totp.qrUrl}" id="mode-barcode">${msg("loginTotpScanBarcode")}</a></p>
                    </li>
                    <li>
                        <p>${msg("loginTotpManualStep3")}</p>
                        <p>
                        <ul>
                            <li id="kc-totp-type">${msg("loginTotpType")}: ${msg("loginTotp." + totp.policy.type)}</li>
                            <li id="kc-totp-algorithm">${msg("loginTotpAlgorithm")}: ${totp.policy.getAlgorithmKey()}</li>
                            <li id="kc-totp-digits">${msg("loginTotpDigits")}: ${totp.policy.digits}</li>
                            <#if totp.policy.type = "totp">
                                <li id="kc-totp-period">${msg("loginTotpInterval")}: ${totp.policy.period}</li>
                            <#elseif totp.policy.type = "hotp">
                                <li id="kc-totp-counter">${msg("loginTotpCounter")}: ${totp.policy.initialCounter}</li>
                            </#if>
                        </ul>
                        </p>
                    </li>
                <#else>
                    <li>
                        <p>${msg("loginTotpStep2")}</p>
                        <img id="kc-totp-secret-qr-code" src="data:image/png;base64, ${totp.totpSecretQrCode}" alt="Figure: Barcode"><br/>
                        <p><a href="${totp.manualUrl}" id="mode-manual">${msg("loginTotpUnableToScan")}</a></p>
                    </li>
                </#if>
            </ol>

            <form action="${url.loginAction}" class="nm-form" id="kc-totp-settings-form" method="post">
                <ol>
                    <li>
                        <p>${msg("loginTotpStep3")}</p>
                        <p>${msg("loginTotpStep3DeviceName")}</p>
                    </li>
                </ol>

                <div class="nm-fields">
                    <div class="nm-field">
                        <label for="totp">${msg("authenticatorCode")} <span class="nm-req">*</span></label>
                        <div class="nm-input">
                            <input type="text" id="totp" name="totp" autocomplete="off"
                                   aria-invalid="<#if messagesPerField.existsError('totp')>true</#if>"/>
                        </div>
                        <#if messagesPerField.existsError('totp')>
                            <span id="input-error-otp-code" class="nm-error" aria-live="polite">${kcSanitize(messagesPerField.get('totp'))?no_esc}</span>
                        </#if>
                        <input type="hidden" id="totpSecret" name="totpSecret" value="${totp.totpSecret}" />
                        <#if mode??><input type="hidden" id="mode" name="mode" value="${mode}"/></#if>
                    </div>

                    <div class="nm-field">
                        <label for="userLabel">${msg("loginTotpDeviceName")} <#if totp.otpCredentials?size gte 1><span class="nm-req">*</span></#if></label>
                        <div class="nm-input">
                            <input type="text" id="userLabel" name="userLabel" autocomplete="off"
                                   aria-invalid="<#if messagesPerField.existsError('userLabel')>true</#if>"/>
                        </div>
                        <#if messagesPerField.existsError('userLabel')>
                            <span id="input-error-otp-label" class="nm-error" aria-live="polite">${kcSanitize(messagesPerField.get('userLabel'))?no_esc}</span>
                        </#if>
                    </div>
                </div>

                <@passwordCommons.logoutOtherSessions/>

                <div class="nm-btn-stack">
                    <#if isAppInitiatedAction??>
                        <button type="submit" class="nm-btn nm-btn-primary" id="saveTOTPBtn">
                            ${msg("doSubmit")}
                            <svg class="nm-ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/><polyline points="10 17 15 12 10 7"/><line x1="15" y1="12" x2="3" y2="12"/></svg>
                        </button>
                        <button type="submit" class="nm-btn nm-btn-ghost" id="cancelTOTPBtn" name="cancel-aia" value="true">${msg("doCancel")}</button>
                    <#else>
                        <button type="submit" class="nm-btn nm-btn-primary" id="saveTOTPBtn">
                            ${msg("doSubmit")}
                            <svg class="nm-ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/><polyline points="10 17 15 12 10 7"/><line x1="15" y1="12" x2="3" y2="12"/></svg>
                        </button>
                    </#if>
                </div>
            </form>
        </div>
    </#if>
</@layout.registrationLayout>
