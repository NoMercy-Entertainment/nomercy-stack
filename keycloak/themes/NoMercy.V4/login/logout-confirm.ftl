<#import "template.ftl" as layout>
<@layout.registrationLayout; section>
    <#if section = "header">
        <span class="nm-head">
            <span class="nm-head__title">${msg("logoutConfirmTitle")}</span>
        </span>
    <#elseif section = "form">
        <div id="kc-logout-confirm">
            <p>${msg("logoutConfirmHeader")}</p>

            <form class="nm-form" action="${url.logoutConfirmAction}" method="POST">
                <input type="hidden" name="session_code" value="${logoutConfirm.code}">
                <div class="nm-btn-stack">
                    <input class="nm-btn nm-btn-primary"
                           name="confirmLogout" id="kc-logout" type="submit" value="${msg("doLogout")}"/>
                </div>
            </form>

            <div id="kc-info-message">
                <#if logoutConfirm.skipLink>
                <#else>
                    <#if (client.baseUrl)?has_content>
                        <div class="nm-btn-stack">
                            <a class="nm-btn nm-btn-ghost" href="${client.baseUrl}">${kcSanitize(msg("backToApplication"))?no_esc}</a>
                        </div>
                    </#if>
                </#if>
            </div>
        </div>
    </#if>
</@layout.registrationLayout>
