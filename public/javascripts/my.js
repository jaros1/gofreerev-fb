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
   user_currency_id = document.getElementById('user_currency') ;
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
    if (String.trim(gift_description.value) == '') {
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