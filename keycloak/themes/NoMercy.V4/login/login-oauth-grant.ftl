<#import "template.ftl" as layout>
<@layout.registrationLayout bodyClass="oauth"; section>
    <#if section = "header">
        <span class="nm-head">
            <#if client.attributes.logoUri??>
                <img src="${client.attributes.logoUri}"/>
            </#if>
            <span class="nm-head__title">
                <#if client.name?has_content>
                    ${msg("oauthGrantTitle",advancedMsg(client.name))}
                <#else>
                    ${msg("oauthGrantTitle",client.clientId)}
                </#if>
            </span>
        </span>
    <#elseif section = "form">
        <div id="kc-oauth" class="nm-prose">
            <h3>${msg("oauthGrantRequest")}</h3>
            <ul class="nm-list">
                <#if oauth.clientScopesRequested??>
                    <#list oauth.clientScopesRequested as clientScope>
                        <li>
                            <span><#if !clientScope.dynamicScopeParameter??>
                                        ${advancedMsg(clientScope.consentScreenText)}
                                    <#else>
                                        ${advancedMsg(clientScope.consentScreenText)}: <b>${clientScope.dynamicScopeParameter}</b>
                                </#if>
                            </span>
                        </li>
                    </#list>
                </#if>
            </ul>
            <#if client.attributes.policyUri?? || client.attributes.tosUri??>
                <h3>
                    <#if client.name?has_content>
                        ${msg("oauthGrantInformation",advancedMsg(client.name))}
                    <#else>
                        ${msg("oauthGrantInformation",client.clientId)}
                    </#if>
                    <#if client.attributes.tosUri??>
                        ${msg("oauthGrantReview")}
                        <a href="${client.attributes.tosUri}" target="_blank">${msg("oauthGrantTos")}</a>
                    </#if>
                    <#if client.attributes.policyUri??>
                        ${msg("oauthGrantReview")}
                        <a href="${client.attributes.policyUri}" target="_blank">${msg("oauthGrantPolicy")}</a>
                    </#if>
                </h3>
            </#if>

            <form class="nm-form" action="${url.oauthAction}" method="POST">
                <input type="hidden" name="code" value="${oauth.code}">
                <div class="nm-btn-stack">
                    <button class="nm-btn nm-btn-primary" name="accept" id="kc-login" type="submit">${msg("doYes")}</button>
                    <button class="nm-btn nm-btn-ghost" name="cancel" id="kc-cancel" type="submit">${msg("doNo")}</button>
                </div>
            </form>
        </div>
    </#if>
</@layout.registrationLayout>
