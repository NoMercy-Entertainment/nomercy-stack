<#import "template.ftl" as layout>
<@layout.registrationLayout displayInfo=false; section>
    <#if section = "header" || section = "show-username">
        <#if section = "header">
            ${msg("loginChooseAuthenticator")}
        </#if>
    <#elseif section = "form">

        <form id="kc-select-credential-form" class="${properties.kcFormClass!}" action="${url.loginAction}" method="post">
            <input type="hidden" id="authexec-hidden-input" name="authenticationExecution"/>
            <div class="${properties.kcSelectAuthListClass!}">
                <#list auth.authenticationSelections as authenticationSelection>
                    <button type="button" class="${properties.kcSelectAuthListItemClass!}"
                            onclick="document.getElementById('authexec-hidden-input').value='${authenticationSelection.authExecId}'; this.form.submit();">
                        <div class="${properties.kcSelectAuthListItemIconClass!}">
                            <i class="${properties['${authenticationSelection.iconCssClass}']!authenticationSelection.iconCssClass} ${properties.kcSelectAuthListItemIconPropertyClass!}"></i>
                        </div>
                        <div class="${properties.kcSelectAuthListItemBodyClass!}">
                            <span class="${properties.kcSelectAuthListItemHeadingClass!}">
                                ${msg('${authenticationSelection.displayName}')}
                            </span>
                            <span class="${properties.kcSelectAuthListItemDescriptionClass!}">
                                ${msg('${authenticationSelection.helpText}')}
                            </span>
                        </div>
                        <div class="${properties.kcSelectAuthListItemFillClass!}"></div>
                        <div class="${properties.kcSelectAuthListItemArrowClass!}">
                            <i class="${properties.kcSelectAuthListItemArrowIconClass!}"></i>
                        </div>
                    </button>
                </#list>
            </div>
        </form>

    </#if>
</@layout.registrationLayout>

