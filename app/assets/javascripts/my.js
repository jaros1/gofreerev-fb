// freeze user_currency when user enters text for new gift (auto submit when currency changes)
function gifts_index_disabled_user_currency() {
    var currency_id;
    currency_id = document.getElementById('user_currency');
    alert('gifts_index_disabled_user_currency, isDisabled = ' + currency_id.isDisabled);

    currency_id.disabled = true;
    var field_id;
    field_id = document.getElementById('gift_price');
    if (field_id.value != '') {
        currency_id.disabled = true;
        return
    }
    field_id = document.getElementById('gift_description');
    if (field_id.value != '') {
        currency_id.disabled = true;
        return
    }
    field_id = document.getElementById('gift_file');
    if (field_id.value != '') {
        currency_id.disabled = true
    }
} // gifts_index_disabled_user_currency


// functions used in page header. Update user currency and return to current page
function default_pre_update_currency() {
    // use this function to check for other pending changes in currency page before submit
    // eg a confirm popup or maybe copy not saved information to hidden variables in update_currency_form before submit
    return true; // continue
    return false; // stop
} // default_pre_update_currency
pre_update_currency = default_pre_update_currency ;
function update_currency() {
    // check if submit is ok (are there other unsaved data in page?)
    var user_currency_new_id;
    var user_currency_old_id;
    user_currency_new_id = document.getElementById('user_currency_new');
    user_currency_old_id = document.getElementById('user_currency_old');
    if (!pre_update_currency()) {
        // unsaved pending data - abort currency change
        user_currency_new_id.value = user_currency_old_id.value ;
        return;
    }
    // get selected currency
    var user_currency_new;
    var update_currency_div_id;
    var update_currency_form_id;
    var user_currency_id;
    user_currency_new = user_currency_new_id.value;
    // copy selected currency to hidden form and submit
    update_currency_div_id = document.getElementById('update_currency_div');
    update_currency_form_id = update_currency_div_id.getElementsByTagName('Form')[0];
    user_currency_id = document.getElementById('user_new_currency');
    user_currency_id.value = user_currency_new;
    update_currency_form_id.submit();
} // update_currency_submit

// Version of pre_update_currency to be used in gifts controller pages
var pending_gift_msg = 'Update currency?';
function gifts_pre_update_currency() {
    // get selected currency
    var user_currency_new_id;
    var user_currency_new;
    var update_currency_div_id;
    var update_currency_form_id;
    var user_currency_id;
    user_currency_new_id = document.getElementById('user_currency_new');
    user_currency_new = user_currency_new_id.value;
    if (user_currency_new == '<%= @user.currency %>') return false;
    // check for pending new gift
    var pending_data = false;
    field_id = document.getElementById('gift_price');
    if (field_id.value != '') pending_data = true;
    field_id = document.getElementById('gift_description');
    if (field_id.value != '') pending_data = true;
    field_id = document.getElementById('gift_file');
    if (field_id.value != '') pending_data = true;
    if (!pending_data) return true; // no pending gift
    // confirm box
    return (confirm(pending_gift_msg));
} // gifts_pre_update_currency()


// Client side validations
// https://github.com/bcardarella/client_side_validations gem was not ready for rails 4 when this app was developed

function csv_empty_field (id)
{
    var value = document.getElementById(id).value ;
    if (!value) return true ;
    if ($.trim(value) == '') return true ;
    return false ;
} // csv_required_field

// Check price - allow decimal comma/point, max 2 decimals. Thousands separators not allowed
// used for price in gift and comment
// should be identical to ruby function invalid_price? in application controller
function csv_invalid_price (id)
{
    if (csv_empty_field(id)) return false ; // empty field - ok
    var price = document.getElementById(id).value ;
    price = $.trim(price);
    var r = new RegExp('^[0-9]*((\.|,)[0-9]{0,2})?$');
    if (!r.test(price) || (price == '.') || (price == ',')) return true ;
    return false ;
} // csv_invalid_price

// Client side validation for new gift
// These error texts are replaced with language-specific texts in gifts/index page
var csv_gift_description_required = 'Description is required.';
var csv_gift_price_invalid = 'Price is invalid. Only numbers, max 2 decimals, thousands separator not allowed.';
function csv_gift() {
    // check required description
    if (csv_empty_field('gift_description')) {
        alert(csv_gift_description_required);
        return false;
    }
    // check optional price. Allow decimal comma/point, max 2 decimals. Thousands separators not allowed
    if (csv_invalid_price('gift_price')) {
        alert(csv_gift_price_invalid);
        return false;
    }
    // gift is ok. ready for submit

    // clear any old (error) messages in page header
    clear_flash_and_ajax_errors() ;

    if (!Modernizr.meter) return true; // process bar not supported
    var progressbar_div = document.getElementById('progressbar-div') ;
    if (!progressbar_div) return true ; // no progressbar found in page

    progressbar_div.style.display = 'block';
    // start upload process bar
    // http://www.hongkiat.com/blog/html5-progress-bar/
    var progressbar = $('#progressbar'),
        max = progressbar.attr('max'),
        time = (1000 / max) * 5,
        value = 0;

    var loading = function () {
        value += 3;
        addValue = progressbar.val(value);

        $('.progress-value').html(value + '%');

        if (value >= max) {
            clearInterval(animate);
            progressbar_div.style.display = 'none';
        }
    };

    var animate = setInterval(function () {
        loading();
    }, time);

    return true;
} // csv_gift


// Client side validation for new comment
// These error texts are replaced with language-specific texts in gifts/index page
var csv_comment_comment_required = 'Comment is required.' ;
var csv_comment_price_invalid = 'Price is invalid. Only numbers, max 2 decimals, thousands separator not allowed.' ;
function csv_comment(giftid)
{
    // check required comment
    if (csv_empty_field("gift-" + giftid + "-comment-new-textarea")) {
        alert(csv_comment_comment_required);
        return false;
    }
    // check optional price. Allow decimal comma/point, max 2 decimals. Thousands separators not allowed
    if (csv_invalid_price('gift-' + giftid + '-comment-new-price')) {
        alert(csv_comment_price_invalid);
        return false;
    }
    // comment is ok - add post ajax handler and submit
    var table_id = 'gift-' + giftid + '-comment-new-errors' ;
    var table = document.getElementById(table_id) ;
    if (table) clear_ajax_errors(table_id) ;
    clear_flash_and_ajax_errors() ;
    post_ajax_add_new_comment_handler(giftid) ;
    return true ;
} // csv_comment


// this ajax flash is used when inserting or updating gifts and comments in gifts table
// todo: add some kind of flash when removing (display=none) rows from gifts table
function ajax_flash (id)
{
    $('#' + id).css({'background-color':'green'}).animate({'background-color':'white'}, 2000) ;
} // ajax_flash

// ajax flash for row table rows - for example new rows in ajax_task_errors table
function ajax_flash_new_table_rows (tablename, number_of_rows)
{
    add2log('ajax_flash_new_table_rows: table_name = ' + tablename + ', number_of_rows = ' + number_of_rows) ;
    var table = document.getElementById(tablename) ;
    if (!table) return ;
    var rows = table.rows ;
    if (rows.length < number_of_rows) number_of_rows = rows.length ;
    var now = (new Date()).getTime() ;
    var id ;
    for (i=rows.length-number_of_rows ; i < rows.length ; i++) {
        id = 'afe-' + now + '-' + i ;
        rows[i].id = id
        ajax_flash(id) ;
    } // for
} // ajax_flash_new_table_rows


// check for new messages once every 15, 60 or 300 seconds
// once every 15 seconds for active users - once every 5 minutes for inactive users
// onclick event on remote link check-new-messages-link"
var check_new_messages_interval ; // interval in seconds between each new messages check
var check_new_messages_interval_id ; // interval id for setInterval function
var last_user_ajax_comment_at ; // timestamp (JS Date) for last new comment created by user

function calculate_new_messages_interval()
{
    var difference ;
    // how often should client check for new messages?
    if (!last_user_ajax_comment_at)
        check_new_messages_interval = 300 ;
    else {
        difference = ((new Date).getTime() - last_user_ajax_comment_at.getTime()) / 1000 ;
        if (difference < 120) check_new_messages_interval = 15 ;
        else if (difference > 600) check_new_messages_interval = 300 ;
        else check_new_messages_interval = 60  ;
    }
    return check_new_messages_interval ;
} // calculate_new_messages_interval

function start_check_new_messages()
{
    $(document).ready(
        function () {
            var interval = calculate_new_messages_interval() ;
            check_new_messages_interval_id = setInterval(function () {
                // call util/new_messages_count and insert response in new_messages_buffer_div in page header
                // information about number off unread messages
                // + new gifts to be inserted in top of page gifts/index page
                // + new comments to be inserted in gifts/index page
                // + todo: changed gifts and comments to be replaced in gifts/index page
                // is post ajax processed in JS functions update_new_messages_count, update_title and insert_new_comments
                var check_new_messages_link = document.getElementById("check-new-messages-link");
                // update newest_gift_id and newest_status_update_at before ajax request.
                // only newer gifts (>newest_gift_id) are ajax inserted in gifts/index page
                // only gifts and comments with > newest_status_update_at are ajax replaced into gifts/index page
                // update newest_gift_id
                var newest_gift_id = document.getElementById("newest-gift-id");
                var newest_gift_id_new_value ;
                if (newest_gift_id && (newest_gift_id.value != '')) newest_gift_id_new_value = newest_gift_id.value ;
                else newest_gift_id_new_value = '0' ;
                var href = check_new_messages_link.href ;
                href = href.replace(/newest_gift_id=[0-9]+/, 'newest_gift_id=' + newest_gift_id_new_value) ;
                // update newest_status_update_at
                var newest_status_update_at = document.getElementById("newest-status-update-at");
                var newest_status_update_at_new_value ;
                if (newest_status_update_at && (newest_status_update_at.value != '')) newest_status_update_at_new_value = newest_status_update_at.value ;
                else newest_status_update_at_new_value = '0' ;
                // replace and click => ajax request to util/new_messages_count => update page
                href = href.replace(/newest_status_update_at=[0-9]+/, 'newest_status_update_at=' + newest_status_update_at_new_value) ;
                check_new_messages_link.href = href ;
                check_new_messages_link.click();
            }, interval * 1000);
        });
} // start_check_new_messages

function restart_check_new_messages()
{
    var old_check_new_messages_interval = check_new_messages_interval ;
    var new_check_new_messages_interval = calculate_new_messages_interval() ;
    if (check_new_messages_interval_id && (old_check_new_messages_interval == new_check_new_messages_interval)) return ; // no change
    if (check_new_messages_interval_id) clearInterval(check_new_messages_interval_id);
    check_new_messages_interval_id = null ;
    start_check_new_messages() ;
} // restart_check_new_messages
// do it
start_check_new_messages() ;


// 3. functions used in util/new_messages_count ajax call.

// update new message count in page header +  insert new comments in page
function update_new_messages_count() {
    // restart setInterval function if refresh period has changed
    restart_check_new_messages() ;
    var new_messages_count_div = document.getElementById("new_messages_count_div");
    if (!new_messages_count_div) return; // div not found
    // responsive layout - two page header layouts - two new message count divs
    var new_messages_count = document.getElementById("new_messages_count1");
    if (new_messages_count) new_messages_count.innerHTML = new_messages_count_div.innerHTML
    var new_messages_count = document.getElementById("new_messages_count2");
    if (new_messages_count) new_messages_count.innerHTML = new_messages_count_div.innerHTML
}
// update_new_messages_count
function update_title() {
    var new_mesaages_count = document.getElementById('new_messages_count');
    var no_new_messages = new_mesaages_count.innerHTML;
    // alert(no_new_messages) ;
    if (no_new_messages == '')
        var new_title = 'Gofreerev';
    else
        var new_title = '(' + no_new_messages + ') Gofreerev';
    document.title = new_title;
} // update_title

function insert_new_comments() {
    var debug = false ;
    var new_comments_tbody, new_comments_trs, new_comment_tr, new_comment_id, new_comment_id_split, new_comment_gift_id, new_comment_comment_id;
    var old_comments_tbody_id, old_comments1_tbody, old_comments1_trs, old_comments1_tr, old_comments1_tr_id;
    var i, j, old_comments2_trs, old_comments2_tr, re1, re2, old_length, old_comments2_length, old_comments2_tr_id;
    var old_comments2_comment_id, inserted, old_comments2_tr_id_split, new_comments_length;
    var summary ; // for debug info.
    var gifts, old_comments2_add_new_comment_tr ;
    if (debug) alert('insert_new_comments') ;
    gifts = document.getElementById("gifts") ;
    if (!gifts) {
        // no gifts table - not gifts/index page
        if (debug) alert('no gifts table - not gifts/index page') ;
        return ;
    }
    new_comments_tbody = document.getElementById("new_comments_tbody");
    if (!new_comments_tbody) {
        if (debug) alert('new_comments_tbody was not found');
        return; // ignore error silently
    }
    new_comments_trs = new_comments_tbody.rows;
    new_comments_length = new_comments_trs.length ;
    if (new_comments_length == 0) {
        // no new comments
        if (debug) alert('no new comments') ;
        return;
    }
    // find old gift rows (header, links, comments, footers)
    old_comments1_trs = gifts.rows ;
    if (old_comments1_trs.length == 0) {
        // no old gifts
        if (debug) alert('no old gifts') ;
        return
    }
    old_comments1_tbody = old_comments1_trs[0].parentNode ;
    // insert new comments in gifts/index page. Loop for each new comment.
    summary = 'Summary. ' +  new_comments_length + ' messages received' ;
    re1 = new RegExp("^gift-[0-9]+-comment-[0-9]+$") ;
    for (i=new_comments_length-1; i >= 0 ; i--) {
        // find gift id and comment id. id format format: gift-218-comment-174
        new_comment_tr = new_comments_trs[i];
        new_comment_id = new_comment_tr.id;
        if (!new_comment_id || !new_comment_id.match(re1)) {
            if (debug) alert('invalid id format ' + new_comment_id) ;
            continue ;
        }
        new_comment_id_split = new_comment_id.split("-");
        new_comment_gift_id = new_comment_id_split[1];
        new_comment_comment_id = parseInt(new_comment_id_split[3]);
        summary = summary + '. ' + i + ', id = ' + new_comment_id ;
        summary = summary + '. ' + i + ', split[3] = ' + new_comment_id_split[3] ;
        if (debug) alert('i = ' + i + ', gift id = ' + new_comment_gift_id + ', comment id = ' + new_comment_comment_id);
        // find any old comments with format gift-218-comment-174
        re2 = new RegExp("^gift-" + new_comment_gift_id + "-comment-[0-9]+$") ;
        old_comments2_trs = [];
        old_comments2_add_new_comment_tr = null ;
        old_length = old_comments1_trs.length;
        for (j = 0; j < old_length; j++) {
            old_comments1_tr = old_comments1_trs[j];
            old_comments1_tr_id = old_comments1_tr.id;
            if (old_comments1_tr_id.match(re2)) old_comments2_trs.push(old_comments1_tr);
            if (old_comments1_tr_id == "gift-" + new_comment_gift_id + "-comment-new") old_comments2_add_new_comment_tr = old_comments1_tr ;
        } // end old comments loop
        if (!old_comments2_add_new_comment_tr) {
            // gift was not found - that is ok
            if (debug) alert('Gift ' + new_comment_gift_id + ' was not found') ;
            continue ;
        }
        old_comments2_length = old_comments2_trs.length;
        // alert('old length = ' + old_length + ', new length = ' + new_length);
        if (old_comments2_length == 0) {
            // insert first comment for gift before add new comment row
            new_comments_tbody.removeChild(new_comment_tr) ;
            old_comments1_tbody.insertBefore(new_comment_tr, old_comments2_add_new_comment_tr);
            ajax_flash(new_comment_tr.id) ;
            if (debug) alert('First comment ' + new_comment_comment_id + ' for gift ' + new_comment_gift_id);
            continue;
        }
        // insert new comment in old comment table (sorted by ascending comment id)
        inserted = false;
        for (j = old_comments2_length-1; ((!inserted) && (j >= 0)); j--) {
            // find comment id for current row
            old_comments2_tr = old_comments2_trs[j];
            old_comments2_tr_id = old_comments2_tr.id;
            old_comments2_tr_id_split = old_comments2_tr_id.split('-') ;
            old_comments2_comment_id = parseInt(old_comments2_tr_id_split[3]);
            if (debug) alert('j = ' + j + ', new comment id = ' + new_comment_comment_id + ', old id = ' + old_comments2_tr_id + ', old comment id = ' + old_comments2_comment_id);
            if (new_comment_comment_id > old_comments2_comment_id) {
                // insert after current row
                new_comments_tbody.removeChild(new_comment_tr) ;
                old_comments2_tr.parentNode.insertBefore(new_comment_tr, old_comments2_tr.nextSibling);
                ajax_flash(new_comment_tr.id) ;
                inserted = true ;
                summary = summary + '. ' + i + ': comment ' + new_comment_comment_id + ' inserted (b) for gift id ' + new_comment_gift_id  ;
                continue;
            }
            if (new_comment_comment_id == old_comments2_comment_id) {
                // new comment already in old comments table
                // replace old comment with new comment
                // alert('comment ' + new_comment_comment_id + ' is already in page');
                old_comments2_tr.id = "" ;
                new_comments_tbody.removeChild(new_comment_tr) ;
                old_comments2_tr.parentNode.insertBefore(new_comment_tr, old_comments2_tr.nextSibling);
                ajax_flash(new_comment_tr.id) ;
                old_comments2_tr.parentNode.removeChild(old_comments2_tr) ;
                inserted = true;
                summary = summary + '. ' + i + ': comment ' + new_comment_comment_id + ' inserted (c) for gift id ' + new_comment_gift_id  ;
                continue;
            }
            // insert before current row - continue loop
        } // end old comments loop
        if (!inserted) {
            // insert before first old comment
            // alert('insert new comment ' + new_comment_id + ' first in old comments table');
            old_comments2_tr = old_comments2_trs[0];
            if (debug) alert('old_comments2_tr = ' + old_comments2_tr) ;
            new_comments_tbody.removeChild(new_comment_tr) ;
            old_comments2_tr.parentNode.insertBefore(new_comment_tr, old_comments2_tr);
            ajax_flash(new_comment_tr.id) ;
            summary = summary + '. ' + i + ': comment ' + new_comment_comment_id + ' inserted (d) for gift id ' + new_comment_gift_id  ;
        } // if
    } // end new comments loop
    if (debug) alert(summary) ;
} // insert_new_comments

// tasks_sleep: missing: no tasks - number: sleep (milliseconds) before executing tasks - for example post status on api walls
function insert_update_gifts (tasks_sleep)
{
    // process ajax response received from new_messages_count ajax request
    // response has been inserted in new_messages_buffer_div in page header
    // also used after util/accept_new_deal to ajax replace gift
    // add2log('insert_update_gifts: start') ;

    // check/update newest_gift_id (id for latest created gift)
    var new_newest_gift_id = document.getElementById("new-newest-gift-id") ; // from new_messages_buffer_div
    if (!new_newest_gift_id) return ; // ok - not gifts/index page or no new/updated/deleted gifts
    if  (new_newest_gift_id.value != "") {
        // util/new_message_count returned new newest giftid
        var newest_gift_id = document.getElementById("newest-gift-id") ;
        if (!newest_gift_id) return // error - hidden field was not found i gifts/index page - ignore error silently
        newest_gift_id.value = new_newest_gift_id.value ;
    }

    // check/update newest_status_update_at (stamp for latest updated or deleted gift )
    var new_newest_status_update_at = document.getElementById("new-newest-status-update-at") ; // from new_messages_buffer_div
    if (!new_newest_status_update_at) return ; // ok - not gifts/index page or no new/updated/deleted gifts
    if  (new_newest_status_update_at.value != "") {
        // util/new_message_count returned new newest status_update_at
        var newest_status_update_at = document.getElementById("newest-status-update-at") ;
        if (!newest_status_update_at) return // error - hidden field was not found i gifts/index page - ignore error silently
        newest_status_update_at.value = new_newest_status_update_at.value ;
    }

    // check if new_messages_count response has a table with new gifts (new_messages_buffer_div in page header)
    var new_gifts_tbody = document.getElementById("new_gifts_tbody") ;
    if (!new_gifts_tbody) return ; // ok - not gifts/index page or no new gifts to error tbody with new gifts was not found
    // find gift ids received in new_gifts_tbody table. Any existing old rows with these gift ids must be removed before inserting new rows
    var new_gifts_trs = new_gifts_tbody.rows ;
    var new_gifts_tr ;
    var new_gifts_id ;
    var new_gifts_gift_id ;
    var new_gifts_ids = [] ;
    var re = new RegExp('^gift-[0-9]+-') ;
    for (var i=0 ; i<new_gifts_trs.length ; i++) {
        new_gifts_id = new_gifts_trs[i].id ;
        if (new_gifts_id && new_gifts_id.match(re)) {
            new_gifts_gift_id = new_gifts_id.split('-')[1] ;
            if (new_gifts_ids.indexOf(new_gifts_gift_id) == -1) new_gifts_ids.push(new_gifts_gift_id) ;
        } // if
    } // for
    // alert('new_gifts_trs.length = ' + new_gifts_trs.length + ', new_gifts_ids = ' + new_gifts_ids.join(',')) ;
    // old page: find first gift row in gifts table. id format gift-220-header.
    // new gifts from ajax response are to be inserted before this row
    var old_gifts_table = document.getElementById("gifts") ;
    if (!old_gifts_table) return ; // not gifts/index page - ok
    var old_gifts_trs = old_gifts_table.rows ;
    var old_gifts_tr ;
    var old_gifts_id ;
    var old_gifts_gift_id ;
    if (new_gifts_ids.length > 0) {
        // remove any old gift rows found in new_gifts_ids array
        // will be replaced by new gift rows from new_messages_buffer_div
        for (i=old_gifts_trs.length-1 ; i>= 0 ; i--) {
            old_gifts_tr = old_gifts_trs[i] ;
            old_gifts_id = old_gifts_tr.id ;
            if (old_gifts_id && old_gifts_id.match(re)) {
                old_gifts_gift_id = old_gifts_id.split('-')[1] ;
                if (new_gifts_ids.indexOf(old_gifts_gift_id) != -1) {
                    // remove old row with gift id. old_gifts_gift_id from gifts table
                    old_gifts_tr.parentNode.removeChild(old_gifts_tr) ;
                } // if
            } // if
        } // for
    } // if
    add2log(old_gifts_trs.length + ' gifts lines in old page') ;
    var old_gifts_index ;
    for (var i=0 ; (!old_gifts_index && (i<old_gifts_trs.length)) ; i++) {
        if (old_gifts_trs[i].id.match(re)) old_gifts_index = i ;
    } // for
    add2log('old_gifts_index = ' + old_gifts_index) ;
    // check for first row to be inserted in gifts table - for example for a new gofreerev user
    if ((!old_gifts_index) && (old_gifts_trs.length >= 1) && (old_gifts_trs.length <= 2)) old_gifts_index = old_gifts_trs.length-1 ;
    if (!old_gifts_index) return ; // error - id with format format gift-<999>-1 was not found - ignore error silently
    var first_old_gift_tr = old_gifts_trs[old_gifts_index] ;
    var old_gifts_tbody = first_old_gift_tr.parentNode ;
    // new gifts from ajax response are to be inserted before first_old_gift_tr
    for (i=new_gifts_trs.length-1 ; i>= 0 ; i--) {
        new_gifts_tr = new_gifts_trs[i] ;
        if (new_gifts_tr.id.match(re)) {
            // insert before "first_old_gift_tr" and move "first_old_gift_tr" to new inserted row
            new_gifts_tr.parentNode.removeChild(new_gifts_tr) ;
            old_gifts_tbody.insertBefore(new_gifts_tr, first_old_gift_tr) ;
            first_old_gift_tr = new_gifts_tr ;
            ajax_flash(first_old_gift_tr.id) ;
        } // if
    } // for
    // that's it

    add2log('ajax_insert_update_gift: ajax_tasks_sleep = ' + tasks_sleep) ;
    if (!tasks_sleep) return ;
    // execute some more tasks - for example post status on api wall(s)
    trigger_tasks_form(tasks_sleep);
} //  insert_update_gifts

// catch load errors  for api pictures. Gift could have been deleted. url could have been changed
// gift ids with invalid picture urls are collected in a global javascript array and submitted to server in 2 seconds
// on error gift.api_picture_url_on_error_at is set and a new picture url is looked up if possible
// JS array with gift ids
var missing_api_picture_urls = [];
// function used in onload for img tags
function imgonload(img) {
    api_gift_id = img.dataset.id ;
    add2log('imgonload. api gift id = ' + api_gift_id + ', img.width = ' + img.width + ', img.height = ' + img.height +
        ', naturalWidth = ' + img.naturalWidth + ', naturalHeight = ' + img.naturalHeight + ', complete = ' + img.complete) ;
    if ((img.width <= 1) && (img.height <= 1)) {
        // image not found - url expired or api picture deleted
        // alert('changed picture url: gift_id = ' + giftid + ', img = ' + img + ', width = ' + img.width + ', height = ' + img.height) ;
        missing_api_picture_urls.push(api_gift_id);
    }
    else if ((img.naturalWidth <= 1) && (img.naturalHeight <= 1)) {
        // image not found - url expired or api picture deleted
        // alert('changed picture url: gift_id = ' + giftid + ', img = ' + img + ', width = ' + img.width + ', height = ' + img.height) ;
        missing_api_picture_urls.push(api_gift_id);
    }
    else {
        // image found. rescale
        img.width = 200;
    }
} // imgonload
// function used in onload for img tags
function imgonerror(img) {
    api_gift_id = img.dataset.id ;
    add2log('imgonerror. api gift id = ' + api_gift_id + ', img.width = ' + img.width + ', img.height = ' + img.height +
        ', naturalWidth = ' + img.naturalWidth + ', naturalHeight = ' + img.naturalHeight + ', complete = ' + img.complete) ;
    missing_api_picture_urls.push(api_gift_id);
} // imgonerror


// function to report gift ids with invalid urls. Submitted in end of gifts/index page
function report_missing_api_picture_urls() {
    if (missing_api_picture_urls.length == 0) {
        // no picture urls to check
        add2log('report_missing_api_picture_urls: no picture urls to check') ;
        return;
    }
    // Report ids with invalid picture url
    add2log('report_missing_api_picture_urls: sending api gift ids to server') ;
    var missing_api_picture_urls_local = missing_api_picture_urls.join();
    $.ajax({
        url: "/util/missing_api_picture_urls.js",
        type: "POST",
        data: { api_gifts: {
            ids: missing_api_picture_urls_local}}
    });
    missing_api_picture_urls = [];
} // report_missing_picture_urls

// enable ajax submit for new gifts in gifts/index page
$(document).ready(function () {
    var new_gift = document.getElementById('new_gift');
    if (!new_gift) return; // not gifts/index page
    new_gift.action = '/gifts.js'; // ajax request
    // bind 'myForm' and provide a simple callback function
    // http://malsup.com/jquery/form/#options-object
    $('#new_gift').ajaxForm({
        beforeSubmit: function (formData, jqForm, options) {
            add2log('#new_gift.beforeSubmit');
        },
        success: function (responseText, statusText, xhr, $form) {
            add2log('#new_gift.success');
            document.getElementById('progressbar-div').style.display = 'none';
            var gift_price = document.getElementById('gift_price');
            if (gift_price) gift_price.value = '';
            var gift_description = document.getElementById('gift_description');
            if (gift_description) gift_description.value = '';
            var gift_file = document.getElementById('gift_file');
            if (gift_file) gift_file.value = '';
            var disp_gift_file = document.getElementById('disp_gift_file');
            if (disp_gift_file) disp_gift_file.value = '';
            // first gift for a new gofreerev user - show gifts table - hide no api gift found message
            var gifts = document.getElementById('gifts');
            if (gifts) gifts.style.display = 'inline';
            var no_gifts_div = document.getElementById('no-gifts-div');
            if (no_gifts_div) no_gifts_div.style.display = 'none';
        },
        error: function (jqxhr, textStatus, errorThrown) {
            document.getElementById('progressbar-div').style.display = 'none';
            add2log('#new_gift.error');
            add2log('jqxhr = ' + jqxhr);
            add2log('textStatus = ' + textStatus);
            add2log('errorThrown = ' + errorThrown);
            add_to_tasks_errors('new_form.ajaxform.error: ' + errorThrown + '. check server log for more information.');
        }
    });
});

// auto resize text fields
// found at http://stackoverflow.com/questions/454202/creating-a-textarea-with-auto-resize
var observe;
if (window.attachEvent) {
    observe = function (element, event, handler) {
        element.attachEvent('on' + event, handler);
    };
}
else {
    observe = function (element, event, handler) {
        element.addEventListener(event, handler, false);
    };
}
function autoresize_text_field(text) {
    function resize() {
        text.style.height = 'auto';
        text.style.height = text.scrollHeight + 'px';
    }

    /* 0-timeout to get the already changed text */
    function delayedResize() {
        window.setTimeout(resize, 0);
    }

    observe(text, 'change', resize);
    observe(text, 'cut', delayedResize);
    observe(text, 'paste', delayedResize);
    observe(text, 'drop', delayedResize);
    observe(text, 'keydown', delayedResize);

    text.focus();
    text.select();
    resize();
}



// post ajax processing after inserting older comments for a gift.
// comments/index.js.rb inserts older comments last i comments table
// new lines are surrounded by "gift-<giftid>-older-comments-block-start-<commentid>" and "gift-<giftid>-older-comments-block-end-<commentid>".
// move lines up before "show-older-comments" link and delete link
function post_ajax_add_older_comments_handler(giftid, commentid) {
    // var id = '#gift-' + giftid + '-new-comment-form' ;
    var link_id = 'gift-' + giftid + '-show-older-comments-link-' + commentid;
    $(document).ready(function () {
        $('#' + link_id)
            .bind("ajax:success", function (evt, data, status, xhr) {
                // find tr for old link, first added row and last added row
                var first_row_id = "gift-" + giftid + "-older-comments-block-start-" + commentid;
                var last_row_id = "gift-" + giftid + "-older-comments-block-end-" + commentid;
                // find link
                var link = document.getElementById(link_id);
                if (!link) return; // link not found
                // find tr for link
                var link_tr = link;
                while (link_tr.tagName != 'TR') link_tr = link_tr.parentNode;
                // find first and last added table row
                var first_row = document.getElementById(first_row_id);
                var last_row = document.getElementById(last_row_id);
                if (!first_row || !last_row) return;
                // copy table rows to JS array
                var trs = [];
                var tr = first_row.nextElementSibling;
                while (tr.id != last_row_id) {
                    if (tr.tagName == 'TR') trs.push(tr);
                    tr = tr.nextElementSibling;
                } // while
                // delete table rows from html table
                tr = first_row;
                var next_tr = tr.nextElementSibling;
                do {
                    tr.parentNode.removeChild(tr);
                    tr = next_tr;
                    next_tr = tr.nextElementSibling;
                } while (tr.id != last_row_id) ;
                // insert table rows before old show-older-comments link

                var tbody = link_tr.parentNode;
                while (trs.length > 0) {
                    tr = trs.shift();
                    tbody.insertBefore(tr, link_tr);
                }
                // delete link  (and this event handler)
                link_tr.parentNode.removeChild(link_tr);
            }); // bind ajax:success
    }); // $(document).ready(function(){
} // add_post_ajax_new_comment_handler

// show/hide price and currency in new comment table call
function check_uncheck_new_deal_checkbox(checkbox, giftid)
{
    var tr = document.getElementById("gift-" + giftid + "-comment-new-price-tr") ;
    var new_deal_yn = document.getElementById("gift-" + giftid + "-comment-new-deal-yn") ;
    var price = document.getElementById("gift-" + giftid + "-comment-new-price") ;
    if (checkbox.checked) {
        tr.style.display='block' ;
        new_deal_yn.value = 'Y' ;
    }
    else {
        tr.style.display = 'none' ;
        new_deal_yn.value = '' ;
        price.value = '' ;
    }
    // alert(checkbox);
} // check_uncheck_new_deal_checkbox


//$(document).ready(function() {
//    $("#tasks_form").unbind("ajax:error") ;
//    $("#tasks_form").bind("ajax:error", function(jqxhr, textStatus, errorThrown){
//        add2log('#tasks_form.error');
//        add2log('jqxhr = ' + jqxhr);
//        add2log('textStatus = ' + textStatus);
//        add2log('errorThrown = ' + errorThrown);
//        add_to_tasks_errors('tasks_form.error: ' + errorThrown + '. check server log for more information.') ;
//    })
//})


// only current currency is in currency LOV at response time
// download all currencies when user clicks on currency LOV
// for smaller page and faster startup time
// todo: minor problem. User has to click twice on currency LOV to change currency. First to get full currency list and second to change currency
$(document).ready(function() {
    $("#user_currency_new").bind('focus', function () {
        var id_select = document.getElementById("user_currency_new");
        if (id_select.length > 1) {
            // list of currencies is already initialised
            $("#user_currency_new").unbind('focus');
        }
        else {
            // get full list of currencies from server
            $.ajax({
                type: 'GET',
                url: '/util/currencies.js',
                dataType: "text",
                success: function (msg) {
                    $("#user_currency_new").unbind('focus');
                    if (msg == 0) {
                        // Query returned empty.
                        add2log('Did not get any currencies from server');  // todo: or just ignore error!
                    } else {
                        // Query Has values.
                        $('#user_currency_new').replaceWith(msg);
                        $("#user_currency_new").click;
                    }
                },
                error: function (jqXHR, textStatus, errorThrown) {
                    $("#user_currency_new").unbind('focus');
                    add2log('error: jqXHR = ' + jqXHR + ', textStatus = ' + textStatus + ', errorThrown = ' + errorThrown);
                }
            });

        }
    }); // $("#user_currency_new").bind('focus', function () {
})

// disable user_currency_new LOV for deep link for not logged in users (gifts/show/<deep_link_id>)
function disable_user_currency_new_lov() {
    setInterval(function() {
        $("#user_currency_new").unbind('focus') ;
    }, 100) ;
} // disable_user_currency_new_lov

// for client side debugging - writes JS messages to debug_log div - only used if DEBUG_AJAX = true
function add2log (text) {
    var log = document.getElementById('debug_log') ;
    if (!log) return ;
    log.innerHTML = log.innerHTML + text + '<br>' ;
} // add2log


// implementing show-more-rows ajax / endless expanding page ==>
// used in gifts/index, users/index and users/show pages

// show-more-rows click. Starts ajax request to gifts or users controller
function show_more_rows()
{
    var link = document.getElementById("show-more-rows-link") ;
    if (!link) return ;
    link.click() ;
} // show_more_rows()

// end_of_page - true or false
// true when user is near end of page (get more rows)
// true under an active get more rows ajax request
// is set in $(window).scroll
// is unset in $(document).ready when new rows has been received
// default not active. end_of_page = true. will be overwritten in gifts/index, users/index and users/show pages
var end_of_page = true ;

// check number of rows in table (gifts or users) before and after get more rows ajax event
// do not fire any more get more rows ajax events if no new rows has been received (server side error)
var old_number_of_rows ;

// remember timestamp in milliseconds for last show-more-rows ajax request
// should only request more rows once every 3 seconds
var old_show_more_rows_request_at = 0 ;

// scroll event - click show_more_rows when user scrolls to end of page
// table_name should be gifts or users
// interval should be 3000 = 3 seconds between each show-more-rows request
// debug true - display messages for ajax debugging in button of page
function show_more_rows_scroll(table_name, interval, debug) {
    if (end_of_page) return; // no more rows, not an ajax expanding page or ajax request already in progress
    if (($(document).height() - $(window).height()) - $(window).scrollTop() < 600) {
        end_of_page = true;
        if (!document.getElementById("show-more-rows-link")) return;
        var table = document.getElementById(table_name);
        if (!table) return; // not
        old_number_of_rows = table.rows.length;
        var now = (new Date()).getTime();
        // There is a minor problem with wait between show-more-rows request
        // Implemented here and implemented in get_next_set_of_rows_error? and get_next_set_of_rows methods in application controller
        // For now wait is 3 seconds in javascript/client and 2 seconds in rails/server
        var sleep = interval - (now - old_show_more_rows_request_at);
        if (sleep < 0) sleep = 0;
        if (debug) add2log('Sleep ' + (sleep / 1000.0) + ' seconds' + '. old timestamp ' + old_show_more_rows_request_at + ', new timestamp ' + now);
        old_show_more_rows_request_at = now + sleep;
        add2log('show_more_rows_scroll: table_name = ' + table_name || '. call show_more_rows in ' + sleep || ' milliseconds');
        if (sleep == 0) show_more_rows();
        else setTimeout("show_more_rows()", sleep);
    }
} // show_more_rows_scroll

function show_more_rows_success (table_name, debug)
{
    if (table_name == 'gifts') {
        // report any invalid api picture urls - url has changed or picture has been deleted
        // array with gift ids is initialized in img onload="imgonload ..."
        // submitted in 2 seconds to allow pictures in page to load
        // api_picture_url_on_error_at is set for pictures with invalid urls
        // picture urls are checked with api calls by current user and if necessary by picture owner at a later time
        setTimeout(report_missing_api_picture_urls, 2000);
    }
    // find id for last row (nil or id for last row in table)
    var pgm = "#show-more-rows-link.ajax:success: " ;
    var link = document.getElementById("show-more-rows-link") ;
    if (!link) {
        if (debug) add2log(pgm + "show-more-rows-link has already been removed");
        return
    }
    var table = document.getElementById(table_name) ;
    if (!table) {
        if (debug) add2log(pgm + 'error - gifts or users table was not found') ;
        return
    }
    var new_number_of_rows = table.rows.length ;
    if (new_number_of_rows == old_number_of_rows) {
        if (debug) add2log(pgm + 'error - no new rows was returned from get more rows ajax request') ;
        return
    }
    var trs = table.getElementsByTagName('tr') ;
    var tr = trs[trs.length-1] ;
    var tr_id = tr.id ;
    if (tr_id == "") {
        if (debug) add2log(pgm + 'no more rows - remove link') ;
        link.parentNode.removeChild(link);
    }
    else {
        var reg = new RegExp("^last-row-id-[0-9]+$") ;
        if (!tr_id.match(reg)) {
            if (debug) add2log(pgm + 'row with format last-row-id-<n> was not found. id = ' + tr_id);
            return
        }
        var tr_id_a = tr_id.split("-") ;
        var last_row_id = tr_id_a[tr_id_a.length-1] ;
        var href = link.href ;
        href = href.replace(/last_row_id=[0-9]+/, 'last_row_id=' + last_row_id) ;
        link.href = href ;
        add2log(pgm + 'href = ' + href)
        end_of_page = false ;
    }
} // show_more_rows_success

function show_more_rows_error(jqxhr, textStatus, errorThrown, debug) {
    if (debug) {
        add2log('show_more_rows.ajax.error');
        add2log('jqxhr = ' + jqxhr);
        add2log('textStatus = ' + textStatus);
        add2log('errorThrown = ' + errorThrown);
    }
    add_to_tasks_errors('show_more_rows.ajax.error: ' + errorThrown + '. check server log for more information.') ;
} // show_more_rows_error

function show_more_rows_ajax(table_name, debug) {
    var link = '#show-more-rows-link'
    $(link).unbind("ajax:success");
    $(link).bind("ajax:success", function (evt, data, status, xhr) {
        show_more_rows_success(table_name, debug);
    });
    $(link).unbind("ajax:error");
    $(link).bind("ajax:error", function (jqxhr, textStatus, errorThrown) {
        show_more_rows_error(jqxhr, textStatus, errorThrown, debug);
    });
} // show_more_rows_ajax



// <== implementing show-more-rows ajax / endless expanding page


// clear error messages in page header before ajax request. For example before submitting new gift

function clear_ajax_errors(table_id) {
    // empty table with ajax messages if any
    var table = document.getElementById(table_id) ;
    if (!table) return ;
    var rows = table.rows ;
    var row ;
    for (var i=rows.length-1 ; i>= 0 ; i--) {
        row = rows[i] ;
        row.parentNode.removeChild(row) ;
    } // for
} // clear_ajax_errors

function clear_flash_and_ajax_errors() {
    // clear old flash message if any
    var notification = document.getElementById('notification');
    if (notification) notification.innerHTML = '' ;
    // empty table with task (error) messages if any
    clear_ajax_errors('tasks_errors') ;
} // clear_flash_and_ajax_errors



function get_js_timezone() {
  return -(new Date().getTimezoneOffset()) / 60.0 ;
}


// request server to execute any task in task queue
// called from bottom of application layout and from  insert_update_gifts after gift create (posting on api wall)
// tasks: get currency rates, download api information (picture, permissions, friend list), post on api walls
function trigger_tasks_form (sleep) {
    add2log("trigger_tasks_form: sleep = " + sleep) ;
    if (!sleep) sleep=1000 ;
    var timezone = document.getElementById("timezone") ;
    if (!timezone) {
        add2log('trigger_tasks_form. hidden field with id timezone was not found') ;
        return ;
    }
    timezone.value = get_js_timezone();
    window.setTimeout(function(){$('#tasks_form').trigger('submit.rails');}, sleep);
} // trigger_tasks_form

// error callback for executing tasks - write to debug log + page header
// debug log in bottom of page is shown if DEBUG_AJAX = true (constants.rb)
$(document).ready(function() {
    $("#tasks_form").unbind("ajax:error") ;
    $("#tasks_form").bind("ajax:error", function(jqxhr, textStatus, errorThrown){
        add2log('#tasks_form.error');
        add2log('jqxhr = ' + jqxhr);
        add2log('textStatus = ' + textStatus);
        add2log('errorThrown = ' + errorThrown);
        add_to_tasks_errors('tasks_form.error: ' + errorThrown + '. check server log for more information.') ;
    })
})


// error callback for comment actions (cancel, accept, reject, delete - write to debug log + page header
$(document).ready(function() {
    $(".comment-action-link").unbind("ajax:beforeSend") ;
    $(".comment-action-link").unbind("ajax:error") ;
    $(".comment-action-link").bind("ajax:beforeSend", function(xhr, settings){
        clear_flash_and_ajax_errors() ;
    })
    $(".comment-action-link").bind("ajax:error", function(jqxhr, textStatus, errorThrown){
        add2log('.comment-action-link.error');
        add2log('jqxhr = ' + jqxhr);
        add2log('textStatus = ' + textStatus);
        add2log('errorThrown = ' + errorThrown);
        add_to_tasks_errors('comment-action-link.error: ' + errorThrown + '. check server log for more information.') ;
    })
})


// normally tasks errors and messages are injected from server
// this function is used for client side errors - for example from error in callback functions (ajax:error)
function add_to_tasks_errors2 (table_id, error) {
    var pgm = 'add_to_tasks_errors2: ' ;
    var table = document.getElementById(table_id) ;
    if (!table) {
        add2log(pgm + table_id + ' was not found.') ;
        add2log(pgm + 'error was ' + error + '') ;
        return ;
    }
    var length = table.rows.size ;
    add2log(pgm + 'length = ' + length) ;
    var row = table.insertRow(length) ;
    var cell = row.insertCell(0) ;
    cell.innerHTML = error ;
    ajax_flash_new_table_rows(table_id, 1);
} // add_to_tasks_errors2

function add_to_tasks_errors (error) {
    var table = document.getElementById('tasks_errors') ;
    if (!table) {
        add2log('add_to_tasks_errors: tasks_errors table was not found.') ;
        add2log('add_to_tasks_errors: error was ' + error + '') ;
        return ;
    }
    var length = table.length ;
    var row = table.insertRow(length) ;
    var cell = row.insertCell(0) ;
    cell.innerHTML = error ;
    ajax_flash_new_table_rows('tasks_errors', 1);
}

// create missing gift-<giftid>-links-errors table if possible
// is created under current gift link row in gifts table
function create_gift_links_errors_table (table_id) {
    var re1 = new RegExp('^gift-[0-9]+-links-errors$') ;
    if (!table_id.match(re1)) return false ; // not a gift link error
    giftid = table_id.split('-')[1] ;
    add2log('giftid = ' + giftid) ;
    ref_id = 'gift-' + giftid + '-links' ;
    add2log('ref_id = ' + ref_id) ;
    ref = document.getElementById(ref_id) ;
    if (!ref) {
        add2log(ref_id + ' was not found. ' + msg) ;
        return false ;
    }
    // add2log(ref_id + ' blev fundet') ;
    ref = ref.nextSibling ;
    if (!ref) {
        add2log('row after ' + ref_id + ' was not found. ' + msg) ;
        return false ;
    }
    add2log('create new tr') ;
    new_tr = document.createElement('tr') ;
    new_tr.id = table_id + '-tr' ;
    add2log('insert new td')
    for (j=0 ; j <= 2 ; j++) {
        new_td = new_tr.insertCell(j) ;
        new_td.innerHTML = '' ;
    }
    add2log('initialize tr[2]')
    new_td.innerHTML = '<table id="' + table_id + '"></table>' ;
    new_td.setAttribute("colspan",2);
    add2log('insertBefore') ;
    ref.parentNode.insertBefore(new_tr, ref) ;
    // ok - new gift link error table has been created
    add2log('ok. ' + table_id + ' has been created') ;
    return true ;
} // create_gift_links_errors_table

// error callback for gift actions (like, unlike, follow, unfollow etc - write to debug log + page header
$(document).ready(function() {
    $(".gift-action-link").unbind("ajax:beforeSend") ;
    $(".gift-action-link").unbind("ajax:error") ;
    $(".gift-action-link").bind("ajax:beforeSend", function(xhr, settings){
        // clear any old ajax error messages if any
        // clear within page ajax error messages if any
        // todo: this event handler is not call for delete gift. Suspect rails confirm dialog is the problem.
        var pgm = 'gift-action-link::ajax:beforeSend. ' ;
        // add2log(pgm + 'xhr = ' + xhr + ', settings = ' + settings) ;
        var url = xhr.target ;
        // add2log(pgm + 'url = ' + url) ;
        var url_a = ('' + url + '').split('=') ;
        // add2log(pgm + 'url_a.length = ' + url_a.length) ;
        var giftid = url_a[url_a.length-1] ;
        // add2log(pgm + 'giftid = ' + giftid) ;
        var table_id = 'gift-' + giftid + '-links-errors' ;
        var table = document.getElementById(table_id) ;
        if (table) clear_ajax_errors(table_id) ;
        // else add2log(pgm + table_id + ' was not found.') ;
        // clear page header error messages if any
        clear_flash_and_ajax_errors() ;
    })
    $(".gift-action-link").bind("ajax:error", function(jqxhr, textStatus, errorThrown){
        add2log('.gift-action-link.error');
        add2log('jqxhr = ' + jqxhr);
        add2log('jqxhr.target = ' + jqxhr.target);
        add2log('textStatus = ' + textStatus);
        add2log('errorThrown = ' + errorThrown);
        // inject gift action ajax error into page if possible. Otherwise use tasks_errors table in page header
        var url = jqxhr.target ;
        // add2log('gift-action-link::ajax:beforeSend. url = ' + url) ;
        var url_a = ('' + url + '').split('=') ;
        // add2log('gift-action-link::ajax:beforeSend. url_a.length = ' + url_a.length) ;
        var giftid = url_a[url_a.length-1] ;
        // add2log('gift-action-link::ajax:beforeSend. giftid = ' + giftid) ;
        var table_id = 'gift-' + giftid + '-links-errors' ;
        var table = document.getElementById(table_id) ;
        if (!table && !create_gift_links_errors_table(table_id)) {
            // inject ajax error message in page header
            add_to_tasks_errors('gift-action-link.error: ' + errorThrown + '. check server log for more information.') ;
        }
        else {
            // inject ajax error message in gift link error table in page
            add_to_tasks_errors2(table_id, 'gift-action-link.error: ' + errorThrown + '. check server log for more information.') ;
        }
    })
})

function create_new_com_errors_table(table_id) {
    // table_id = gift-890-comment-new-errors
    var pgm = 'create_new_com_errors_table: ' ;
    var re1 = new RegExp('^gift-[0-9]+-comment-new-errors$') ;
    if (!table_id.match(re1)) return false ; // not a new comment error
    giftid = table_id.split('-')[1] ;
    add2log(pgm + 'giftid = ' + giftid) ;
    ref_id = 'gift-' + giftid + '-comment-new-price-tr' ;
    add2log(pgm + 'ref_id = ' + ref_id) ;
    ref = document.getElementById(ref_id) ;
    if (!ref) {
        add2log(pgm + ref_id + ' was not found. ') ;
        return false ;
    }
    // find table with gift-<giftid>-comment-new-price-tr row
    var tbody = ref.parentNode ;
    var rows = tbody.rows ;
    add2log(pgm + rows.length + ' rows in table') ;
    if (rows.length != 3) {
        add2log(pgm + 'Expected 3 rows in table with ' + ref_id + '. Found ' + rows.length + ' rows.') ;
        return false ;
    }
    // add new table row with table for ajax error messages
    var row = tbody.insertRow(rows.length) ;
    var cell = row.insertCell(0) ;
    cell.setAttribute("colspan",2);
    cell.innerHTML = '<table id="' + table_id + '"></table>' ;
    add2log(pgm + table_id + ' has been created') ;
    return true ;
} // create_new_com_errors_table

// post ajax processing after adding a comment.
// comments/create.js.rb inserts new comment as last row i gifts table
// move new comment from last row to row before new comment row
// clear comment text area and reset frequency for new message check
function post_ajax_add_new_comment_handler(giftid) {
    var fnc = 'post_ajax_add_new_comment_handler: ' ;
    var id = '#gift-' + giftid + '-new-comment-form';
    $(id).unbind("ajax:success");
    $(id).bind("ajax:success", function (evt, data, status, xhr) {
        var checkbox, gifts, trs, re, i, new_comment_tr, id2, add_new_comment_tr, tbody;
        // reset new comment line
        document.getElementById('gift-' + giftid + '-comment-new-price').value = '';
        document.getElementById('gift-' + giftid + '-comment-new-textarea').value = '';
        document.getElementById('gift-' + giftid + '-comment-new-price-tr').style.display = 'none';
        checkbox = document.getElementById('gift-' + giftid + '-new-deal-check-box');
        if (checkbox) checkbox.checked = false;
        // find new comment table row last in gifts table
        gifts = document.getElementById("gifts");
        trs = gifts.rows;
        re = new RegExp("^gift-" + giftid + "-comment-[0-9]+$");
        i = trs.length - 1;
        for (i = trs.length - 1; ((i >= 0) && !new_comment_tr); i--) {
            id2 = trs[i].id;
            if (id2 && id2.match(re)) new_comment_tr = trs[i];
        } // for
        if (!new_comment_tr) {
            add2log(fnc + "new comment row with format " + re + " was not found. There could be more information in server log.");
            return;
        }
        add_new_comment_tr = document.getElementById("gift-" + giftid + "-comment-new");
        if (!add_new_comment_tr) {
            add2log(fnc + "gift-" + giftid + "-comment-new was not found");
            return;
        }
        // move new table row up before add new comment table row
        new_comment_tr.parentNode.removeChild(new_comment_tr);
        add_new_comment_tr.parentNode.insertBefore(new_comment_tr, add_new_comment_tr); // error: Node was not found
        // save timestamp for last new ajax comment
        last_user_ajax_comment_at = new Date();
        restart_check_new_messages();
    });
    $(id).unbind("ajax:error");
    $(id).bind("ajax:error", function(jqxhr, textStatus, errorThrown){
        add2log(fnc + 'ajax.error');
        add2log('jqxhr = ' + jqxhr);
        add2log('textStatus = ' + textStatus);
        add2log('errorThrown = ' + errorThrown);

        var table_id = 'gift-' + giftid + '-comment-new-errors' ;

        var table = document.getElementById(table_id) ;
        if (!table && !create_new_com_errors_table(table_id)) {
            // inject ajax error message in page header
            add_to_tasks_errors(fnc + 'ajax.error: ' + errorThrown + '. check server log for more information.') ;
        }
        else {
            // inject ajax error message in new comment error table in page
            add_to_tasks_errors2(table_id, fnc + 'ajax.error: ' + errorThrown + '. check server log for more information.') ;
        }
    });
} // post_ajax_add_new_comment_handler


// try to move ajax error messages from tasks_errors2 to more specific location in page
// first column is error message. Second column is id for error table in page
// tasks_errors table in page header will be used of more specific location can not be found
function move_tasks_errors2() {
    var from_table = document.getElementById('tasks_errors2') ;
    if (!from_table) {
        add_to_tasks_errors('tasks_errors2 was not found') ;
        return ;
    }
    var rows = from_table.rows ;
    var lng = rows.length ;
    var row, cells, msg, to_table_id, to_table ;
    var re1, giftid, ref_id, ref, new_tr, new_td, j ;
    // add2log(lng + ' rows in tasks_errors2 table') ;
    for (var i=lng-1 ; i >= 0 ; i--) {
        row = rows[i] ;
        cells = row.cells ;
        if (cells.length != 2) {
            add_to_tasks_errors('Invalid number of cells in tasks_errors row ' + i + '. Expected 2 cells. Found ' + cells.length + ' cells') ;
            continue ;
        }
        msg = cells[0].innerHTML ;
        to_table_id = cells[1].innerHTML ;
        add2log('msg = ' + msg + ', to_table_id = ' + to_table_id) ;
        // use to_table if to_table already exists
        to_table = document.getElementById(to_table_id) ;
        if (!to_table) {
            // create missing table
            if (!create_gift_links_errors_table(to_table_id) &&
                !create_new_com_errors_table(to_table_id)) {
                // could not create inside page error table
                add_to_tasks_errors(msg + ' (inject not implemented for error message with id ' + to_table_id + ').') ;
                continue
            }
            // error table was created
            to_table = document.getElementById(to_table_id) ;
        }
        // move error message
        add_to_tasks_errors2(to_table_id, msg) ;
        row.parentNode.removeChild(row) ;
    } // for
    // alert('move_tasks_errors2. lng = ' + lng);
} // move_tasks_errors2

// ajax enable/disable gift file field in gifts/index page
// enable after granting write permission to aåi wall
// disable after revoking last write permission to api wall
function disable_enable_file_upload (gift_file_enabled) {
   // add2log('disable_enable_file_upload: gift_file_enabled = ' + gift_file_enabled) ;
   if (gift_file_enabled === undefined) return;
   var gift_file = document.getElementById('gift_file');
   if (!gift_file) return ;
   gift_file.disabled = !gift_file_enabled ;
   // add2log('gift_file.disabled = ' + gift_file.disabled) ;
} // disable_enable_file_upload


// display cookie_note div for the first SHOW_COOKIE_NOTE seconds when a new user visits gofreerev
function hide_cookie_note() {
    var cookie_node = document.getElementById('cookie_note') ;
    if (!cookie_node) return ;
    cookie_node.style.display = 'none' ;
} // hide_cookie_note


// set JS timezone in tasks form
// send to server in util/to_tasks
$(document).ready(function() {
    var timezone = document.getElementById("timezone") ;
    if (!timezone) return ;
    timezone.value = get_js_timezone();
    // add2log('timezone = ' + timezone.value) ;
})

// gifts/index page - copy rows from hidden_tasks_errors to tasks_errors - links to grant write permission to api walls
$(document).ready(function() {
    var from_table = document.getElementById('hidden_tasks_errors') ;
    if (!from_table) return ; // not gifts/index page
    var to_table = document.getElementById('tasks_errors') ;
    var from_trs = from_table.rows ;
    for (var i=from_trs.length-1; i>= 0 ; i--) {
        var tr = from_trs[i];
        from_table.deleteRow(i) ;
        to_table.appendChild(tr) ;
    }
});

// custom confirm box - for styling
// http://lesseverything.com/blog/archives/2012/07/18/customizing-confirmation-dialog-in-rails/
// http://www.pjmccormick.com/nicer-rails-confirm-dialogs-and-not-just-delete-methods
// tried with coffee script. Tried with javascript. not working.
/*
$.rails.allowAction = function(link) {
    if (!link.attr('data-confirm')) {
        return true;
    }
    $.rails.showConfirmDialog(link);
    return false;
};

$.rails.confirmed = function(link) {
    link.removeAttr('data-confirm');
    return link.trigger('click.rails');
};

$.rails.showConfirmDialog = function(link) {
    var html;
    html = "<div id=\"dialog-confirm\" title=\"Are you sure you want to delete?\">\n  <p>These item will be permanently deleted and cannot be recovered. Are you sure?</p>\n</div>";
    return $(html).dialog({
        resizable: false,
        modal: true,
        buttons: {
            OK: function() {
                $.rails.confirmed(link);
                return $(this).dialog("close");
            },
            Cancel: function() {
                return $(this).dialog("close");
            }
        }
    });
};
*/


