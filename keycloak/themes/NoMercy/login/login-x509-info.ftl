<#import "template.ftl" as layout>
<@layout.registrationLayout; section>
    <#if section = "header">
        <span class="nm-head">
            <span class="nm-head__title">${msg("doLogIn")}</span>
        </span>
    <#elseif section = "form">
        <form id="kc-x509-login-info" class="nm-form" action="${url.loginAction}" method="post">
            <div class="nm-fields">
                <div class="nm-field">
                    <label for="certificate_subjectDN">${msg("clientCertificate")}</label>
                    <#if x509.formData.subjectDN??>
                        <div class="nm-input">
                            <label id="certificate_subjectDN">${(x509.formData.subjectDN!"")}</label>
                        </div>
                    <#else>
                        <div class="nm-input">
                            <label id="certificate_subjectDN">${msg("noCertificate")}</label>
                        </div>
                    </#if>
                </div>

                <#if x509.formData.isUserEnabled??>
                    <div class="nm-field">
                        <label for="username">${msg("doX509Login")}</label>
                        <div class="nm-input">
                            <label id="username">${(x509.formData.username!'')}</label>
                        </div>
                    </div>
                </#if>
            </div>

            <div class="nm-btn-stack">
                <button class="nm-btn nm-btn-primary" name="login" id="kc-login" type="submit">${msg("doContinue")}</button>
                <#if x509.formData.isUserEnabled??>
                    <button class="nm-btn nm-btn-ghost" name="cancel" id="kc-cancel" type="submit">${msg("doIgnore")}</button>
                </#if>
            </div>
        </form>
    </#if>
</@layout.registrationLayout>
