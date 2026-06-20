<#import "template.ftl" as layout>
<@layout.registrationLayout displayMessage=true; section>
    <#if section = "header">
        <span class="nm-head">
            <span class="nm-head__title">${kcSanitize(msg("webauthn-error-title"))?no_esc}</span>
        </span>
    <#elseif section = "form">

        <script type="text/javascript">
            refreshPage = () => {
                document.getElementById('isSetRetry').value = 'retry';
                document.getElementById('executionValue').value = '${execution}';
                document.getElementById('kc-error-credential-form').submit();
            }
        </script>

        <form id="kc-error-credential-form" class="nm-form" action="${url.loginAction}"
              method="post">
            <input type="hidden" id="executionValue" name="authenticationExecution"/>
            <input type="hidden" id="isSetRetry" name="isSetRetry"/>
        </form>

        <div class="nm-btn-stack">
            <input onclick="refreshPage()" type="button"
                   class="nm-btn nm-btn-primary"
                   name="try-again" id="kc-try-again" value="${kcSanitize(msg("doTryAgain"))?no_esc}"
            />

            <#if isAppInitiatedAction??>
                <form action="${url.loginAction}" class="nm-form" id="kc-webauthn-settings-form" method="post">
                    <button type="submit"
                            class="nm-btn nm-btn-ghost"
                            id="cancelWebAuthnAIA" name="cancel-aia" value="true">${msg("doCancel")}
                    </button>
                </form>
            </#if>
        </div>

    </#if>
</@layout.registrationLayout>
