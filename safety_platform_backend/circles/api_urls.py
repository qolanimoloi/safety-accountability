from django.urls import path

from . import api_views as v

urlpatterns = [
    path("", v.circle_list_create, name="circle_list_create"),
    path("monitor/", v.monitor_rules, name="circle_monitor"),
    path("proposals/<int:pk>/vote/", v.proposal_vote, name="circle_proposal_vote"),
    path("<int:pk>/", v.circle_detail, name="circle_detail"),
    path("<int:pk>/invite/", v.circle_invite, name="circle_invite"),
    path("<int:pk>/respond/", v.circle_respond, name="circle_respond"),
    path("<int:pk>/leave/", v.circle_leave, name="circle_leave"),
    path("<int:pk>/members/<int:user_id>/remove/", v.member_remove, name="circle_member_remove"),
    path("<int:pk>/members/<int:user_id>/promote/", v.member_promote, name="circle_member_promote"),
    path("<int:pk>/home/", v.my_home, name="circle_home"),
    path("<int:pk>/curfew/", v.circle_curfew, name="circle_curfew"),
    path("<int:pk>/zones/", v.zone_create, name="circle_zone_create"),
    path("<int:pk>/zones/<int:zone_id>/", v.zone_delete, name="circle_zone_delete"),
    path("<int:pk>/proposals/", v.proposal_list, name="circle_proposals"),
    path("<int:pk>/alerts/", v.circle_alerts, name="circle_alerts"),
]