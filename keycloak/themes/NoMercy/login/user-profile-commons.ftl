<#macro userProfileFormFields>
	<#assign currentGroup="">

	<#list profile.attributes as attribute>

		<#assign groupName = attribute.group!"">
		<#if groupName != currentGroup>
			<#assign currentGroup=groupName>
			<#if currentGroup != "" >
				<#assign groupDisplayHeader=attribute.groupDisplayHeader!"">
				<#if groupDisplayHeader != "">
					<#assign groupHeaderText=advancedMsg(attribute.groupDisplayHeader)!groupName>
				<#else>
					<#assign groupHeaderText=groupName>
				</#if>
				<div class="nm-group">
					<label id="header-${groupName}" class="nm-group__title">${groupHeaderText}</label>
					<#assign groupDisplayDescription=attribute.groupDisplayDescription!"">
					<#if groupDisplayDescription != "">
						<#assign groupDescriptionText=advancedMsg(attribute.groupDisplayDescription)!"">
						<label id="description-${groupName}" class="nm-group__desc">${groupDescriptionText}</label>
					</#if>
				</div>
			</#if>
		</#if>

		<#nested "beforeField" attribute>
		<div class="nm-field">
			<label for="${attribute.name}">${advancedMsg(attribute.displayName!'')}<#if attribute.required> <span class="nm-req">*</span></#if></label>
			<#if attribute.annotations.inputHelperTextBefore??>
				<div class="nm-field-help" id="form-help-text-before-${attribute.name}" aria-live="polite">${kcSanitize(advancedMsg(attribute.annotations.inputHelperTextBefore))?no_esc}</div>
			</#if>
			<@inputFieldByType attribute=attribute/>
			<#if messagesPerField.existsError('${attribute.name}')>
				<span id="input-error-${attribute.name}" class="nm-error" aria-live="polite">${kcSanitize(messagesPerField.get('${attribute.name}'))?no_esc}</span>
			</#if>
			<#if attribute.annotations.inputHelperTextAfter??>
				<div class="nm-field-help" id="form-help-text-after-${attribute.name}" aria-live="polite">${kcSanitize(advancedMsg(attribute.annotations.inputHelperTextAfter))?no_esc}</div>
			</#if>
		</div>
		<#nested "afterField" attribute>
	</#list>
</#macro>

<#macro inputFieldByType attribute>
	<#switch attribute.annotations.inputType!''>
	<#case 'textarea'>
		<div class="nm-input nm-input--area"><@textareaTag attribute=attribute/></div>
		<#break>
	<#case 'select'>
	<#case 'multiselect'>
		<div class="nm-input"><@selectTag attribute=attribute/></div>
		<#break>
	<#case 'select-radiobuttons'>
	<#case 'multiselect-checkboxes'>
		<@inputTagSelects attribute=attribute/>
		<#break>
	<#default>
		<div class="nm-input"><@inputTag attribute=attribute/></div>
	</#switch>
</#macro>

<#macro inputTag attribute>
	<input type="<@inputTagType attribute=attribute/>" id="${attribute.name}" name="${attribute.name}" value="${(attribute.value!'')}"
		aria-invalid="<#if messagesPerField.existsError('${attribute.name}')>true</#if>"
		<#if attribute.readOnly>disabled</#if>
		<#if attribute.autocomplete??>autocomplete="${attribute.autocomplete}"</#if>
		<#if attribute.annotations.inputTypePlaceholder??>placeholder="${attribute.annotations.inputTypePlaceholder}"</#if>
		<#if attribute.annotations.inputTypePattern??>pattern="${attribute.annotations.inputTypePattern}"</#if>
		<#if attribute.annotations.inputTypeSize??>size="${attribute.annotations.inputTypeSize}"</#if>
		<#if attribute.annotations.inputTypeMaxlength??>maxlength="${attribute.annotations.inputTypeMaxlength}"</#if>
		<#if attribute.annotations.inputTypeMinlength??>minlength="${attribute.annotations.inputTypeMinlength}"</#if>
		<#if attribute.annotations.inputTypeMax??>max="${attribute.annotations.inputTypeMax}"</#if>
		<#if attribute.annotations.inputTypeMin??>min="${attribute.annotations.inputTypeMin}"</#if>
		<#if attribute.annotations.inputTypeStep??>step="${attribute.annotations.inputTypeStep}"</#if>
	/>
</#macro>

<#macro inputTagType attribute>
	<#compress>
	<#if attribute.annotations.inputType??>
		<#if attribute.annotations.inputType?starts_with("html5-")>
			${attribute.annotations.inputType[6..]}
		<#else>
			${attribute.annotations.inputType}
		</#if>
	<#else>
	text
	</#if>
	</#compress>
</#macro>

<#macro textareaTag attribute>
	<textarea id="${attribute.name}" name="${attribute.name}"
		aria-invalid="<#if messagesPerField.existsError('${attribute.name}')>true</#if>"
		<#if attribute.readOnly>disabled</#if>
		<#if attribute.annotations.inputTypeCols??>cols="${attribute.annotations.inputTypeCols}"</#if>
		<#if attribute.annotations.inputTypeRows??>rows="${attribute.annotations.inputTypeRows}"</#if>
		<#if attribute.annotations.inputTypeMaxlength??>maxlength="${attribute.annotations.inputTypeMaxlength}"</#if>
	>${(attribute.value!'')}</textarea>
</#macro>

<#macro selectTag attribute>
	<select id="${attribute.name}" name="${attribute.name}"
		aria-invalid="<#if messagesPerField.existsError('${attribute.name}')>true</#if>"
		<#if attribute.readOnly>disabled</#if>
		<#if attribute.annotations.inputType=='multiselect'>multiple</#if>
		<#if attribute.annotations.inputTypeSize??>size="${attribute.annotations.inputTypeSize}"</#if>
	>
	<#if attribute.annotations.inputType=='select'>
		<option value=""></option>
	</#if>

	<#if attribute.annotations.inputOptionsFromValidation?? && attribute.validators[attribute.annotations.inputOptionsFromValidation]?? && attribute.validators[attribute.annotations.inputOptionsFromValidation].options??>
		<#assign options=attribute.validators[attribute.annotations.inputOptionsFromValidation].options>
	<#elseif attribute.validators.options?? && attribute.validators.options.options??>
		<#assign options=attribute.validators.options.options>
	</#if>

	<#if options??>
		<#list options as option>
		<option value="${option}" <#if attribute.values?seq_contains(option)>selected</#if>><@selectOptionLabelText attribute=attribute option=option/></option>
		</#list>
	</#if>
	</select>
</#macro>

<#macro inputTagSelects attribute>
	<#if attribute.annotations.inputType=='select-radiobuttons'>
		<#assign inputType='radio'>
	<#else>
		<#assign inputType='checkbox'>
	</#if>

	<#if attribute.annotations.inputOptionsFromValidation?? && attribute.validators[attribute.annotations.inputOptionsFromValidation]?? && attribute.validators[attribute.annotations.inputOptionsFromValidation].options??>
		<#assign options=attribute.validators[attribute.annotations.inputOptionsFromValidation].options>
	<#elseif attribute.validators.options?? && attribute.validators.options.options??>
		<#assign options=attribute.validators.options.options>
	</#if>

	<#if options??>
		<div class="nm-otp-creds">
		<#list options as option>
			<label class="nm-check" for="${attribute.name}-${option}">
				<input type="${inputType}" id="${attribute.name}-${option}" name="${attribute.name}" value="${option}"
					aria-invalid="<#if messagesPerField.existsError('${attribute.name}')>true</#if>"
					<#if attribute.readOnly>disabled</#if>
					<#if attribute.values?seq_contains(option)>checked</#if>
				/>
				<span><@selectOptionLabelText attribute=attribute option=option/></span>
			</label>
		</#list>
		</div>
	</#if>
</#macro>

<#macro selectOptionLabelText attribute option>
	<#compress>
	<#if attribute.annotations.inputOptionLabels??>
		${advancedMsg(attribute.annotations.inputOptionLabels[option]!option)}
	<#else>
		<#if attribute.annotations.inputOptionLabelsI18nPrefix??>
			${msg(attribute.annotations.inputOptionLabelsI18nPrefix + '.' + option)}
		<#else>
			${option}
		</#if>
	</#if>
	</#compress>
</#macro>
