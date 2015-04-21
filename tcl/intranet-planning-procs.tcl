# /packages/intranet-planning/tcl/intranet-planning-procs.tcl
#
# Copyright (C) 2003-2010 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_library {
    @author frank.bergmann@project-open.com
}


# ----------------------------------------------------------------------
# Constants
# ----------------------------------------------------------------------

ad_proc -public im_planning_item_status_active {} { return 73000 }
ad_proc -public im_planning_item_status_deleted {} { return 73102 }

ad_proc -public im_planning_item_type_revenues {} { return 73100 }
ad_proc -public im_planning_item_type_costs {} { return 73102 }


# ----------------------------------------------------------------------
# Components
# ---------------------------------------------------------------------

ad_proc -public im_planning_component {
    {-planning_type_id 73100 }
    {-planning_time_dim_id 73202 }
    {-planning_dim1_id "" }
    {-planning_dim2_id "" }
    {-planning_dim3_id "" }
    {-restrict_to_main_project_p 1 }
    -object_id
} {
    Returns a HTML component to show all object related planning items.
    Default values indicate type "Revenue" planning by time dimension "Month".
    No planning dimensions are specified by default, so that means planning
    per project and sub-project normally.
} {
    im_security_alert_check_integer -location "im_planning_component" -value $object_id

    # Skip evaluating the component if we are not in a main project
    set parent_id [util_memoize [list db_string parent "select parent_id from im_projects where project_id = $object_id" -default ""]]
    if {$restrict_to_main_project_p && "" != $parent_id} { return "" }

    set params [list \
		    [list object_id $object_id] \
		    [list planning_type_id $planning_type_id] \
		    [list planning_time_dim_id $planning_time_dim_id] \
		    [list planning_dim1_id $planning_dim1_id] \
		    [list planning_dim2_id $planning_dim2_id] \
		    [list planning_dim3_id $planning_dim3_id] \
    ]

    set result [ad_parse_template -params $params "/packages/intranet-planning/lib/planning-component"]
    return [string trim $result]
}


# ---------------------------------------------------------------------
# Project Assignment Component 
# ---------------------------------------------------------------------
ad_proc -public im_project_assignment_component { 
    -project_id
    -user_id
    -return_url
} { 
} {
    set params [list  [list base_url "/intranet-planning/"]  [list user_id $user_id] [list project_id $project_id] [list return_url [im_biz_object_url $project_id]]]
    
    set result [ad_parse_template -params $params "/packages/intranet-planning/lib/project-assignment"]
    return [string trim $result]
}

# -----------------
# Planning items
# ----------------

namespace eval planning_item {

    ad_proc -public new {
        -item_object_id
	{-item_type_id "73102"}
	{-item_status_id "73000"}
	{-item_project_phase_id ""}
	{-item_project_member_id ""}
	{-item_project_member_hourly_cost ""}
	{-item_cost_type_id ""}
	{-item_date ""}
	{-item_value ""}
	{-item_note ""}
	{ -creation_date "" }
	{ -creation_user "" }
	{ -creation_ip "" }
	{ -context_id "" }

    } {
	Creates a new planning item.

	@author malte.sussdorff@cognovis.de
	@return <code>item_id</code> of the newly created planning_item
	        or 0 in case of an error.
    } {

	# The context of this planning item by default is the item_object_id
	if {"" == $context_id} {
	    set context_id $item_object_id
	}

        if { [empty_string_p $creation_date] } {
	    set creation_date [db_string get_sysdate "select sysdate from dual" -default 0]
        }
        if { [empty_string_p $creation_user] } {
            set creation_user [auth::get_user_id]
        }
        if { [empty_string_p $creation_ip] } {
            set creation_ip [ns_conn peeraddr]
        }

        set item_id [db_exec_plsql create_new_planning_item "select im_planning_item__new (
        NULL,
        'im_planning_item',
        :creation_date,
        :creation_user,
        :creation_ip,
        :context_id,
        :item_object_id,
        :item_type_id,
        :item_status_id,
        :item_value,
        :item_note,
        :item_project_phase_id,
        :item_project_member_id,
        :item_cost_type_id,
        :item_date)"]

        return $item_id
    }

    ad_proc -public get_projects {
        -user_id
        {-start_date ""}
        {-end_date ""}
    } {
        Returns a list of projects the user is planned for in a time period
    } {
        if {"" == $start_date} {
	        set start_date "date_trunc('month', current_date)"
        } else {
	        set start_date "date_trunc('month', to_date('$start_date','YYYY-MM-DD'))"
        }

        if {"" == $end_date} {
	        set end_date "to_date('2099-12-01','YYYY-MM-DD'))"
        } else {
	        set end_date "date_trunc('month', to_date('$end_date','YYYY-MM-DD'))"
        }
	
        return [db_list planned_projects "select distinct item_project_phase_id 
            from im_planning_items 
            where item_project_member_id = :user_id
            and item_date >= $start_date
            and item_date <= $end_date"]
    }

    ad_proc -public get_project_managers {
        -user_id
        {-start_date ""}
	    {-end_date ""}
    } {
        Returns a list of project_managers the user is planned for in a time period
    } {
        set project_ids [planning_item::get_projects -user_id $user_id -start_date $start_date -end_date $end_date]
        if {"" == $project_ids} {
	        return ""
        } else {
	        return [db_list project_mangers "select distinct object_id_two from acs_rels rel, im_biz_object_members bom where rel.rel_id = bom.rel_id and bom.object_role_id = 1301 and object_id_one in ([template::util::tcl_to_sql_list $project_ids])"]
        }
    }

}
