<#import "template.ftl" as layout>
<#-- Terms/privacy always render. A client that has no tosUri/policyUri set falls back to the
     NoMercy links in the message bundle, so consent is never shown without the legal notice. -->
<#assign tosUrl = (client.attributes.tosUri)!msg("nmLegalTosUrl")>
<#assign policyUrl = (client.attributes.policyUri)!msg("nmLegalPrivacyUrl")>
<#assign clientLabel = client.name?has_content?then(advancedMsg(client.name!''), client.clientId)>
<@layout.registrationLayout bodyClass="oauth"; section>
    <#if section = "header">
        <span class="nm-head">
            <#if client.attributes.logoUri??>
                <img class="nm-consent-logo" src="${client.attributes.logoUri}" alt=""/>
            </#if>
            <span class="nm-head__title">${msg("oauthGrantTitle", clientLabel)}</span>
            <span class="nm-head__sub">${msg("nmConsentSubtitle", clientLabel)}</span>
        </span>
    <#elseif section = "form">
        <div id="kc-oauth" class="nm-consent">
            <p class="nm-consent__intro">${msg("nmConsentIntro", clientLabel)}</p>

            <#if oauth.clientScopesRequested??>
                <ul class="nm-list nm-scopes">
                    <#list oauth.clientScopesRequested as clientScope>
                        <#assign scopeText = advancedMsg(clientScope.consentScreenText)!''>
                        <#if scopeText?has_content>
                            <li>
                                <svg class="nm-list__ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"/></svg>
                                <span><#if clientScope.dynamicScopeParameter??>${scopeText}: <b>${clientScope.dynamicScopeParameter}</b><#else>${scopeText}</#if></span>
                            </li>
                        </#if>
                    </#list>
                </ul>
            </#if>

            <p class="nm-consent__legal">
                ${msg("nmConsentLegalPrefix")}
                <a href="${tosUrl}" target="_blank" rel="noopener noreferrer">${msg("nmConsentTos")}</a>
                ${msg("nmConsentLegalAnd")}
                <a href="${policyUrl}" target="_blank" rel="noopener noreferrer">${msg("nmConsentPrivacy")}</a>${msg("nmConsentLegalSuffix")}
            </p>
            <p class="nm-consent__revoke">${msg("nmConsentRevoke")}</p>

            <form class="nm-form nm-consent__form" action="${url.oauthAction}" method="POST">
                <input type="hidden" name="code" value="${oauth.code}">
                <div class="nm-btn-stack">
                    <button class="nm-btn nm-btn-primary" name="accept" id="kc-login" type="submit">${msg("nmConsentAllow")}</button>
                    <button class="nm-btn nm-btn-passkey" name="cancel" id="kc-cancel" type="submit">${msg("nmConsentDeny")}</button>
                </div>
            </form>
        </div>
    </#if>
</@layout.registrationLayout>
