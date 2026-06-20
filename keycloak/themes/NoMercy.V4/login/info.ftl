<#import "template.ftl" as layout>
<@layout.registrationLayout displayMessage=false; section>
    <#if section = "header">
        <span class="nm-head">
            <span class="nm-head__title"><#if messageHeader??>${messageHeader}<#else>${message.summary}</#if></span>
        </span>
    <#elseif section = "form">
        <div id="kc-info-message">
            <p>${message.summary}<#if requiredActions??><#list requiredActions>: <b><#items as reqActionItem>${kcSanitize(msg("requiredAction.${reqActionItem}"))?no_esc}<#sep>, </#items></b></#list><#else></#if></p>
            <#if skipLink??>
            <#else>
                <#if pageRedirectUri?has_content>
                    <div class="nm-btn-stack">
                        <a class="nm-btn nm-btn-primary" href="${pageRedirectUri}">${kcSanitize(msg("backToApplication"))?no_esc}</a>
                    </div>
                <#elseif actionUri?has_content>
                    <div class="nm-btn-stack">
                        <a class="nm-btn nm-btn-primary" href="${actionUri}">${kcSanitize(msg("proceedWithAction"))?no_esc}</a>
                    </div>
                <#elseif (client.baseUrl)?has_content>
                    <div class="nm-btn-stack">
                        <a class="nm-btn nm-btn-primary" href="${client.baseUrl}">${kcSanitize(msg("backToApplication"))?no_esc}</a>
                    </div>
                </#if>
            </#if>
        </div>
    </#if>
</@layout.registrationLayout>
