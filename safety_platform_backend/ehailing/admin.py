from django.contrib import admin
from .models import DriverCommunity, DriverCommunityPost, EhailingPanicAlert, PassengerLog, Trip

admin.site.register(Trip)
admin.site.register(DriverCommunity)
admin.site.register(DriverCommunityPost)
admin.site.register(PassengerLog)
admin.site.register(EhailingPanicAlert)