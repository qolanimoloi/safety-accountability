from django.contrib import admin

from .models import Circle, CircleAlert, CircleMember, Zone

admin.site.register(Circle)
admin.site.register(CircleMember)
admin.site.register(Zone)
admin.site.register(CircleAlert)