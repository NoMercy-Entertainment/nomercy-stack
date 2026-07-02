<#import "template.ftl" as layout>
<@layout.registrationLayout displayInfo=false; section>
    <#if section = "header">
        <span class="nm-head">
            <span class="nm-head__title">${msg("loginChooseAuthenticator")}</span>
        </span>
    <#elseif section = "form">
        <form id="kc-select-credential-form" class="nm-form" action="${url.loginAction}" method="post">
            <input type="hidden" id="authexec-hidden-input" name="authenticationExecution"/>
            <div class="nm-select">
                <#list auth.authenticationSelections as authenticationSelection>
                    <button type="button" class="nm-select-item"
                            onclick="document.getElementById('authexec-hidden-input').value='${authenticationSelection.authExecId}'; this.form.submit();">
                        <span class="nm-select-icon">
                            <i class="${properties['${authenticationSelection.iconCssClass}']!authenticationSelection.iconCssClass}" aria-hidden="true"></i>
                        </span>
                        <span class="nm-select-body">
                            <span class="nm-select-title">${msg('${authenticationSelection.displayName}')}</span>
                            <span class="nm-select-desc">${msg('${authenticationSelection.helpText}')}</span>
                        </span>
                        <svg class="nm-select-arrow" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"/></svg>
                    </button>
                </#list>
            </div>
        </form>
    </#if>
</@layout.registrationLayout>
