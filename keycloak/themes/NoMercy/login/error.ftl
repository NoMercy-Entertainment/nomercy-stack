<#import "template.ftl" as layout>
<@layout.registrationLayout displayMessage=false; section>
    <#if section = "header">
        <span class="nm-head">
            <span class="nm-head__title">${kcSanitize(msg("errorTitle"))?no_esc}</span>
        </span>
    <#elseif section = "form">
        <div id="kc-error-message">
            <p>${kcSanitize(message.summary)?no_esc}</p>
            <#if skipLink??>
            <#else>
                <#if client?? && client.baseUrl?has_content>
                    <div class="nm-btn-stack">
                        <a id="backToApplication" class="nm-btn nm-btn-primary" href="${client.baseUrl}">${kcSanitize(msg("backToApplication"))?no_esc}</a>
                    </div>
                </#if>
            </#if>
        </div>
    </#if>
</@layout.registrationLayout>
