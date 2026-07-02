<#import "template.ftl" as layout>
<@layout.registrationLayout displayMessage=false; section>
    <#if section = "header">
        <span class="nm-head">
            <span class="nm-head__title">${msg("termsTitle")}</span>
        </span>
    <#elseif section = "form">
        <div id="kc-terms-text" class="nm-prose">
            ${kcSanitize(msg("termsText"))?no_esc}
        </div>
        <form class="nm-form" action="${url.loginAction}" method="POST">
            <div class="nm-btn-stack">
                <button class="nm-btn nm-btn-primary" name="accept" id="kc-accept" type="submit">${msg("doAccept")}</button>
                <button class="nm-btn nm-btn-ghost" name="cancel" id="kc-decline" type="submit">${msg("doDecline")}</button>
            </div>
        </form>
    </#if>
</@layout.registrationLayout>
