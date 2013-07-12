// freeze user_currency when user enters text for new gift (auto submit when currency changes)
function gifts_index_disabled_user_currency() {
    var currency_id ;
    currency_id = document.getElementById('user_currency');
    currency_id.disabled = false ;
    var field_id ;
    field_id = document.getElementById('gift_price') ;
    if (field_id.value != '') { currency_id.disabled = true ; return }
    field_id = document.getElementById('gift_description') ;
    if (field_id.value != '') { currency_id.disabled = true ; return }
    field_id = document.getElementById('gift_file') ;
    if (field_id.value != '') { currency_id.disabled = true ; return }
} // gifts_index_disabled_user_currency

//
function update_currency()
{
   // get selected currency
   var user_currency_new_id ;
   var user_currency_new ;
   var update_currency_div_id ;
   var update_currency_form_id ;
   var user_currency_id ;
   user_currency_new_id = document.getElementById('user_currency_new') ;
   user_currency_new = user_currency_new_id.value ;
   // copy selected currency to hidden form and submit
   update_currency_form_id = document.getElementById('edit_user_1') ;
   user_currency_id = document.getElementById('user_currency') ;
   user_currency_id.value = user_currency_new ;
   update_currency_form_id.submit() ;
   // done
} // update_currency
