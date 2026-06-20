<#import "template.ftl" as layout>
<@layout.registrationLayout; section>
    <#if section = "header">
        <span class="nm-head">
            <span class="nm-head__title">${msg("deleteAccountConfirm")}</span>
        </span>
    <#elseif section = "form">
        <form action="${url.loginAction}" class="nm-form" method="post">

            <div class="alert alert-warning" style="margin-top:0 !important;margin-bottom:30px !important">
                <span class="pficon pficon-warning-triangle-o"></span>
                ${msg("irreversibleAction")}
            </div>

            <p>${msg("deletingImplies")}</p>
            <ul style="color: #72767b;list-style: disc;list-style-position: inside;">
                <li>${msg("loggingOutImmediately")}</li>
                <li>${msg("errasingData")}</li>
            </ul>

            <p class="delete-account-text">${msg("finalDeletionConfirmation")}</p>

            <div class="nm-btn-stack">
                <button class="nm-btn nm-btn-primary" type="submit">${msg("doConfirmDelete")}</button>
                <#if triggered_from_aia>
                    <button class="nm-btn nm-btn-ghost" type="submit" name="cancel-aia" value="true">${msg("doCancel")}</button>
                </#if>
            </div>
        </form>
    </#if>
</@layout.registrationLayout>
