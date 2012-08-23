/*
 *  Html5 Form Plugin - jQuery plugin
 *  Version 1.5  / English
 *  
 *  Author: by Matias Mancini http://www.matiasmancini.com.ar
 * 
 *  Copyright (c) 2010 Matias Mancini (http://www.matiasmancini.com.ar)
 *  Dual licensed under the MIT (MIT-LICENSE.txt)
 *  and GPL (GPL-LICENSE.txt) licenses.
 *
 *  Built for jQuery library
 *	http://jquery.com
 *
 */
(function($){
    $.fn.html5form = function(options){
        
        $(this).each(function(){
            
            //default configuration properties
            var defaults = {
                async : false,
                method : $(this).attr('method'), 
                responseDiv : null,
                errorDiv : null,
                errorShowHide : false,
                highlightColor : '#ff4b4b',
                labels : 'show',
                colorOn : '#000000', 
                colorOff : '#a1a1a1', 
                action : $(this).attr('action'),
                messages : false,
                emptyMessage : false,
                emailMessage : false,
                allBrowsers : false
            };   
            var opts = $.extend({}, defaults, options);
            
            //Filter modern browsers 
            if(!opts.allBrowsers){
                //exit if Webkit > 533
                if($.browser.webkit && parseInt($.browser.version) >= 533){
                    return false;
                }
                //exit if Firefox > 4
                if($.browser.mozilla && parseInt($.browser.version) >= 2){
                    return false;   
                }
                //exit if Opera > 11
                if($.browser.opera && parseInt($.browser.version) >= 11){
                    return false;   
                }
                //exit if IE > 10 (future proof)
                if($.browser.msie && parseInt($.browser.version) >= 10){
                    return false;
                } 
            }
                        
            //Private properties
            var form = $(this);
            var required = new Array();
            var email = new Array();

            //Show the error message if            
            function displayError(message, input) {
                if (opts.errorDiv === null) {return;}

                //If the message is a function call it
                if($.isFunction(message)){
                        $(opts.errorDiv).html(message());
                }
                //Otherwise the message is already the content to add, possibly with string replace
                else {
                    //String replace if we were passed in the input field
                    if(input !== null) {
                        //Try to use the title attribute as per HTML5 standard, fallback to name instead of 'undefined'
                        if($(input).attr('title')) {
                            message = message.replace(':input:', $(input).attr('title'));
                        } else {
                            //Sentence case the name
                            var name = $(input).attr('name').charAt(0).toUpperCase() + $(input).attr('name').slice(1);
                            //Swap dash and underscore for space
                            name = name.replace('-', '&nbsp;').replace('_', '&nbsp;');
                            message = message.replace('%input%', name);
                        }
                    }
                    $(opts.errorDiv).html(message); 
                }

                //If we are meant to show a hidden div, do that
                if (opts.errorShowHide) {
                    //If the div is already visible i.e. and error was already present flash it
                    if($(opts.errorDiv).is(":visible")) {
                        $(opts.errorDiv).effect("highlight", {color: opts.highlightColor}, 1000);
                    }
                    //If the div is not visible fade it in
                    else {
                        //Unhide all hidden parents
                        $(opts.errorDiv).parents(':hidden').toggle();
                        $(opts.errorDiv).fadeIn('fast');
                    }
                }
            }

            //Setup color & placeholder function
            function fillInput(input){
                if(input.attr('placeholder') && input.attr('type') != 'password'){
                    input.val(input.attr('placeholder'));
                    input.css('color', opts.colorOff);
                }else{
                    if(!input.data('value')){
                        if(input.val()!=''){
                            input.data('value', input.val());   
                        }
                    }else{
                        input.val(input.data('value'));
                    }   
                    input.css('color', opts.colorOn);
                }
            }
            
            //Label hiding (if required)
            if(opts.labels == 'hide'){
                $(this).find('label').hide();   
            }
            
            //Select event handler (just colors)
            $.each($('select', this), function(){
                $(this).css('color', opts.colorOff);
                $(this).change(function(){
                    $(this).css('color', opts.colorOn);
                });
            });
                        
            //For each textarea & visible input excluding button, submit, radio, checkbox and select
            $.each($(':input:visible:not(:button, :submit, :radio, :checkbox, select)', form), function(i) {
                
                //Setting color & placeholder
                fillInput($(this));
                
                //Make array of required inputs
                if(this.getAttribute('required')!=null){
                    required[i]=$(this);
                }
                
                //Make array of Email inputs               
                if(this.getAttribute('type')=='email'){
                    email[i]=$(this);
                }
                          
                //FOCUS event attach 
                //If input value == placeholder attribute will clear the field
                //If input type == url will not
                //In both cases will change the color with colorOn property                 
                $(this).bind('focus', function(ev){
                    ev.preventDefault();
                    if(this.value == $(this).attr('placeholder')){
                        if(this.getAttribute('type')!='url'){
                            $(this).attr('value', '');   
                        } 
                    }
                    $(this).css('color', opts.colorOn);
                });
                
                //BLUR event attach
                //If input value == empty calls fillInput fn
                //if input type == url and value == placeholder attribute calls fn too
                $(this).bind('blur', function(ev){
                    ev.preventDefault();
                    if(this.value == ''){
                        fillInput($(this));
                    }
                    else{
                        if((this.getAttribute('type')=='url') && ($(this).val()==$(this).attr('placeholder'))){
                            fillInput($(this));
                        }
                    }
                });
                
                //Limits content typing to TEXTAREA type fields according to attribute maxlength
                $('textarea').filter(this).each(function(){
                    if($(this).attr('maxlength')>0){
                        $(this).keypress(function(ev){
                            var cc = ev.charCode || ev.keyCode;
                            if(cc == 37 || cc == 39) {
                                return true;
                            }
                            if(cc == 8 || cc == 46) {
                                return true;
                            }
                            if(this.value.length >= $(this).attr('maxlength')){
                                return false;   
                            }
                            else{
                                return true;
                            }
                        });
                    }
                });
            });
            $.each($('input:submit, input:image, input:button', this), function() {
                $(this).bind('click', function(ev){
                                       
                    var emptyInput=null;
                    var emailError=null;
                    var input = $(':input:visible:not(:button, :submit, :radio, :checkbox, select)', form);                    
                    
                    //Search for empty fields & value same as placeholder
                    //returns first input founded
                    //Add messages for multiple languages
                    $(required).each(function(key, value) {
                        if(value==undefined){
                            return true;
                        }
                        if(($(this).val()==$(this).attr('placeholder')) || ($(this).val()=='')){
                            emptyInput=$(this);
                            if(opts.emptyMessage){
                                //Customized empty message
                                //$(opts.responseDiv).html('<p>'+opts.emptyMessage+'</p>');
                                displayError(opts.emptyMessage, this);
                            }
                            else if(opts.messages=='es'){
                                //Spanish empty message
                                //$(opts.responseDiv).html('<p>El campo '+$(this).attr('title')+' es requerido.</p>');
                                displayError('<p>El campo %input% es requerido.</p>', this);
                            }
                            else if(opts.messages=='en'){
                                //English empty message
                                //$(opts.responseDiv).html('<p>The '+$(this).attr('title')+' field is required.</p>');
                                displayError('<p>The %input% field is required.</p>', this);
                            }
                            else if(opts.messages=='it'){
                                //Italian empty message
                                //$(opts.responseDiv).html('<p>Il campo '+$(this).attr('title')+' &eacute; richiesto.</p>');
                                displayError('<p>Il campo %input% &eacute; richiesto.</p>', this);
                            }
                            else if(opts.messages=='de'){
                                //German empty message
                                //$(opts.responseDiv).html('<p>'+$(this).attr('title')+' ist ein Pflichtfeld.</p>');
                                displayError('<p>%input% ist ein Pflichtfeld.</p>', this);
                            }
                            else if(opts.messages=='fr'){
                                //Frech empty message
                                //$(opts.responseDiv).html('<p>Le champ '+$(this).attr('title')+' est requis.</p>');
                                displayError('<p>Le champ %input% est requis.</p>', this);
                            }
                            else if(opts.messages=='nl' || opts.messages=='be'){
                                //Dutch messages
                                //$(opts.responseDiv).html('<p>'+$(this).attr('title')+' is een verplicht veld.</p>');
                                displayError('<p>%input% is een verplicht veld.</p>', this);
                            }
                            else if(opts.messages=='br'){
                               //Brazilian empty message
                               //$(opts.responseDiv).html('<p>O campo '+$(this).attr('title')+' &eacute; obrigat&oacute;rio.</p>');
                               displayError('<p>O campo %input% &eacute; obrigat&oacute;rio.</p>', this);
                            }
                            else if(opts.messages=='br'){
                                //$(opts.responseDiv).html("<p>Insira um email v&aacute;lido por favor.</p>");
                                displayError(, this);
                            }                   
                            return false;
                        }
                    return emptyInput;
                    });
                        
                    //check email type inputs with regular expression
                    //return first input founded
                    $(email).each(function(key, value) {
                        if(value==undefined){
                            return true;
                        }
                        if($(this).val().search(/[\w-\.]{3,}@([\w-]{2,}\.)*([\w-]{2,}\.)[\w-]{2,4}/i)){
                            emailError=$(this);
                            return false;
                        }
                    return emailError;
                    });
                    
                    //Submit form ONLY if emptyInput & emailError are null
                    //if async property is set to false, skip ajax
                    if(!emptyInput && !emailError){
                        
                        //Clear all empty value fields before Submit 
                        $(input).each(function(){
                            if($(this).val()==$(this).attr('placeholder')){
                                $(this).val('');
                            }
                        }); 
                        //Submit data by Ajax
                        if(opts.async){
                            var formData=$(form).serialize();
                            $.ajax({
                                url : opts.action,
                                type : opts.method,
                                data : formData,
                                success : function(data){
                                    if(opts.responseDiv){
                                        $(opts.responseDiv).html(data);   
                                    }
                                    //Reset form
                                    $(input).val('');
                                    $.each(form[0], function(){
                                        fillInput($(this).not(':hidden, :button, :submit, :radio, :checkbox, select'));
                                        $('select', form).each(function(){
                                            $(this).css('color', opts.colorOff);
                                            $(this).children('option:eq(0)').attr('selected', 'selected');
                                        });
                                        $(':radio, :checkbox', form).removeAttr('checked');
                                    });  
                                }
                            });   
                        }
                        else{
                            $(form).submit();
                        }
                    }else{
                        if(emptyInput){
                            $(emptyInput).focus().select();              
                        }
                        else if(emailError){
                            //Customized email error messages (Spanish, English, Italian, German, French, Dutch)
                            if(opts.emailMessage){
                                //$(opts.responseDiv).html('<p>'+opts.emailMessage+'</p>');
                                displayError(opts.emailMessage);
                            }
                            else if(opts.messages=='es'){
                                //$(opts.responseDiv).html('<p>Ingrese una direcci&oacute;n de correo v&aacute;lida por favor.</p>');
                                displayError('<p>Ingrese una direcci&oacute;n de correo v&aacute;lida por favor.</p>');
                            }
                            else if(opts.messages=='en'){
                                //$(opts.responseDiv).html('<p>Please type a valid email address.</p>');
                                displayError('<p>Please type a valid email address.</p>');
                            }
                            else if(opts.messages=='it'){
                                //$(opts.responseDiv).html("<p>L'indirizzo e-mail non &eacute; valido.</p>");
                                displayError("<p>L'indirizzo e-mail non &eacute; valido.</p>");
                            }
                            else if(opts.messages=='de'){
                                //$(opts.responseDiv).html("<p>Bitte eine g&uuml;ltige E-Mail-Adresse eintragen.</p>");
                                displayError('<p>Bitte eine g&uuml;ltige E-Mail-Adresse eintragen.</p>');
                            }
                            else if(opts.messages=='fr'){
                                //$(opts.responseDiv).html("<p>Entrez une adresse email valide s&rsquo;il vous plait.</p>");
                                displayError('<p>Entrez une adresse email valide s&rsquo;il vous plait.</p>');
                            }
                            else if(opts.messages=='nl' || opts.messages=='be'){
                                //$(opts.responseDiv).html('<p>Voert u alstublieft een geldig email adres in.</p>');
                                displayError('<p>Voert u alstublieft een geldig email adres in.</p>');
                            }
                            else if(opts.messages=='br'){
                                //$(opts.responseDiv).html("<p>Insira um email v&aacute;lido por favor.</p>");
                                displayError('<p>Insira um email v&aacute;lido por favor.</p>');
                            }
                            $(emailError).select();
                        }else{
                            alert('Unknown Error');                        
                        }
                    }
                    return false;
                });
            });
        });
    } 
})(jQuery);
