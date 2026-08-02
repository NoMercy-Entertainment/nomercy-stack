<#import "template.ftl" as layout>
<#-- displayMessage=false on purpose: Keycloak's own "you must verify your email" alert repeats
     the heading and the instruction verbatim, so the page said the same thing three times. The
     heading and subtitle below carry it once. -->
<@layout.registrationLayout displayInfo=true displayMessage=false; section>
    <#if section = "header">
        <span class="nm-head">
            <span class="nm-head__title">${msg("emailVerifyTitle")}</span>
            <span class="nm-head__sub">${msg("emailVerifyInstruction1",user.email)}</span>
        </span>
    <#elseif section = "form">
        <div class="nm-notice">
            <span class="nm-notice__icon" aria-hidden="true">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><rect x="2.5" y="4.5" width="19" height="15" rx="2.5"/><path d="m3 7 8.1 5.4a1.6 1.6 0 0 0 1.8 0L21 7"/></svg>
            </span>
        </div>
    <#elseif section = "info">
        <p class="nm-resend">
            ${msg("emailVerifyInstruction2")}
            <a href="${url.loginAction}">${msg("doClickHere")}</a> ${msg("emailVerifyInstruction3")}
        </p>
    </#if>
</@layout.registrationLayout>
