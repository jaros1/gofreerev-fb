// freeze user_currency when user enters text for new gift (auto submit when currency changes)
function gifts_index_disabled_user_currency() {
    var currency_id ;
    currency_id = document.getElementById('user_currency');
    alert('gifts_index_disabled_user_currency, isDisabled = ' + currency_id.isDisabled) ;

    currency_id.disabled = true ;
    var field_id ;
    field_id = document.getElementById('gift_price') ;
    if (field_id.value != '') { currency_id.disabled = true ; return }
    field_id = document.getElementById('gift_description') ;
    if (field_id.value != '') { currency_id.disabled = true ; return }
    field_id = document.getElementById('gift_file') ;
    if (field_id.value != '') { currency_id.disabled = true }
} // gifts_index_disabled_user_currency


// functions used in page header. Update user currency and return to current page
function pre_update_currency()
{
  // use this function to check for other pending changes in currency page before submit
  // eg a confirm popup or maybe copy not saved information to hidden variables in update_currency_form before submit
  return true ; // continue
  return false ; // stop
} // update_currency_ok
function update_currency()
{
   // check if submit is ok (are there other pending changes in page?)
   if (!pre_update_currency()) return ;
   // get selected currency
   var user_currency_new_id ;
   var user_currency_new ;
   var update_currency_div_id ;
   var update_currency_form_id ;
   var user_currency_id ;
   user_currency_new_id = document.getElementById('user_currency_new') ;
   user_currency_new = user_currency_new_id.value ;
   // copy selected currency to hidden form and submit
   update_currency_div_id = document.getElementById('update_currency_div') ;
   update_currency_form_id = update_currency_div_id.getElementsByTagName('Form')[0] ;
   user_currency_id = document.getElementById('user_new_currency') ;
   user_currency_id.value = user_currency_new ;
   update_currency_form_id.submit() ;
} // update_currency_submit

// Version of pre_update_currency to be used in gifts controller pages
var pending_gift_msg = 'Update currency?' ;
function gifts_pre_update_currency()
{
    // get selected currency
    var user_currency_new_id ;
    var user_currency_new ;
    var update_currency_div_id ;
    var update_currency_form_id ;
    var user_currency_id ;
    user_currency_new_id = document.getElementById('user_currency_new') ;
    user_currency_new = user_currency_new_id.value ;
    if (user_currency_new == '<%= @user.currency %>') return false ;
    // check for pending new gift
    var pending_data = false ;
    field_id = document.getElementById('gift_price') ;
    if (field_id.value != '') pending_data = true ;
    field_id = document.getElementById('gift_description') ;
    if (field_id.value != '') pending_data = true ;
    field_id = document.getElementById('gift_file') ;
    if (field_id.value != '') pending_data = true ;
    if (!pending_data) return true ; // no pending gift
    // confirm box
    return (confirm(pending_gift_msg)) ;
} // gifts_pre_update_currency()


// Client side validations
// https://github.com/bcardarella/client_side_validations gem was not ready for rails 4 when this app was developed


// Client side validation for gifts
var csv_gifts_description_required = 'Description is required.' ;
var csv_gifts_price_invalid = 'Price is invalid. Only numbers, max 2 decimals, thousands separator not allowed.' ;
function gifts_client_validations() {
    // check required description
    var gift_description = document.getElementById('gift_description') ;
    if (!gift_description.value || String.trim(gift_description.value) == '') {
        alert(csv_gifts_description_required) ;
        return false ;
    }
    // check optional price. Allow decimal comma/point, max 2 decimals. Thousands separators not allowed
    var gift_price_id = document.getElementById('gift_price') ;
    var gift_price = String.trim(gift_price_id.value) ;
    var gift_price_valid = true ;
    if (gift_price != '') {
      r = new RegExp('^[0-9]*(\.|,)[0-9]{1,2}$') ;
      if (!r.test(gift_price) || (gift_price == '.') || (gift_price == ',')) {
        alert(csv_gifts_price_invalid);
        return false ;
      }
    }
    // gift is ok. ready for submit
    return true ;
} // gifts_client_validations


// update new message count in menu line once every minute
// ok: firefox, chrome and opera
// not ok:
// not tested: Midori, IE (broken on my laptop)
function update_title()
{
  var new_mesaages_count = document.getElementById('new_mesaages_count');
  var no_new_messages = new_mesaages_count.innerHTML ;
  // alert(no_new_messages) ;
  if (no_new_messages == '')
    var new_title = 'Gofreerev' ;
  else
    var new_title = '(' + no_new_messages + ') Gofreerev' ;
  document.title = new_title ;
} // update_title
// update new message count in menu line once every minute
// todo: change from once every 10 minutes (600000) to once every minute (60000)


// from http://www.alfajango.com/blog/rails-3-remote-links-and-forms/
// for index/gifts page - not working
// see /Disk-0/OLAP-hosting/Ruby/railsapps/ajaxified_scaffold-master
$(document).ready(function(){

    $('#gift-211-new-comment-form')
        .bind("ajax:beforeSend", function(evt, xhr, settings){
            var $submitButton = $(this).find('input[name="commit"]');

            // Update the text of the submit button to let the user know stuff is happening.
            // But first, store the original text of the submit button, so it can be restored when the request is finished.
            $submitButton.data( 'origText', $(this).text() );
            $submitButton.text( "Submitting..." );

        })
        .bind("ajax:success", function(evt, data, status, xhr){
            var $form = $(this);

            // Reset fields and any validation errors, so form can be used again, but leave hidden_field values intact.
            $form.find('textarea,input[type="text"],input[type="file"]').val("");
            $form.find('div.validation-error').empty();

            // Insert response partial into page below the form.
            $('#comments').append(xhr.responseText);

        })
        .bind('ajax:complete', function(evt, xhr, status){
            var $submitButton = $(this).find('input[name="commit"]');

            // Restore the original submit button text
            $submitButton.text( $(this).data('origText') );
        })
        .bind("ajax:error", function(evt, xhr, status, error){
            var $form = $(this),
                errors,
                errorText;

            try {
                // Populate errorText with the comment errors
                errors = $.parseJSON(xhr.responseText);
            } catch(err) {
                // If the responseText is not valid JSON (like if a 500 exception was thrown), populate errors with a generic error message.
                errors = {message: "Please reload the page and try again"};
            }

            // Build an unordered list from the list of errors
            errorText = "There were errors with the submission: \n<ul>";

            for ( error in errors ) {
                errorText += "<li>" + error + ': ' + errors[error] + "</li> ";
            }

            errorText += "</ul>";

            // Insert error list into form
            $form.find('div.validation-error').html(errorText);
        });

});


/*

$(document).ready(
    function(){
        setInterval(function(){
            $('#new_mesaages_count').load('/util/new_messages_count');
            update_title();
        }, 600000);
    });*/

// catch load errors  for api pictures. Gift could have been deleted. url could have been changed
// gift ids with invalid picture urls are collected in a global javascript array and submitted to server in 2 seconds
// on error gift.api_picture_url_on_error_at is setted and a new picture url is looked up if possible
// JS array with gift ids
var missing_api_picture_urls = [] ;
// function used in onload for img tags
function check_api_picture_url (giftid, img)
{
  if ((img.width <= 1) && (img.height <= 1)) {
      // image not found - url expired or api picture deleted
      // alert('changed picture url: gift_id = ' + giftid + ', img = ' + img + ', width = ' + img.width + ', height = ' + img.height) ;
      missing_api_picture_urls.push(giftid) ;
  }
  else {
      // image found. rescale
      img.width = 200 ;
  }
} // check_api_picture_url
// function to report gift ids with invalid urls. Submitted in end of gifts/index page
function report_missing_api_picture_urls()
{
  if (missing_api_picture_urls.length == 0) return ;
  // Report ids with invalid picture url
  var missing_api_picture_urls_local = missing_api_picture_urls.join() ;
  $.ajax({
            url: "/util/missing_api_picture_urls",
            type: "POST",
            data: { gifts: {
                ids: missing_api_picture_urls_local}}
  });
  missing_api_picture_urls = [] ;
} // report_missing_picture_urls

// auto resize text fields
// found at http://stackoverflow.com/questions/454202/creating-a-textarea-with-auto-resize
var observe;
if (window.attachEvent) {
    observe = function (element, event, handler) {
        element.attachEvent('on'+event, handler);
    };
}
else {
    observe = function (element, event, handler) {
        element.addEventListener(event, handler, false);
    };
}
function autoresize_text_field (text) {
    function resize () {
        text.style.height = 'auto';
        text.style.height = text.scrollHeight+'px';
    }
    /* 0-timeout to get the already changed text */
    function delayedResize () {
        window.setTimeout(resize, 0);
    }
    observe(text, 'change',  resize);
    observe(text, 'cut',     delayedResize);
    observe(text, 'paste',   delayedResize);
    observe(text, 'drop',    delayedResize);
    observe(text, 'keydown', delayedResize);

    text.focus();
    text.select();
    resize();
}