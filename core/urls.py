"""
URL configuration for core project.
"""

from django.contrib import admin
from django.urls import path, include
from .views import health_check

urlpatterns = [
    path('health/', health_check, name='health-check'),
    path('api/health/', health_check, name='api-health-check'),
    path('admin/', admin.site.urls),
    path('api/', include('tools.urls')),
    path('api/', include('tax_chat.urls')),
]
