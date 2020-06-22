package rundeck.services

import com.dtolabs.rundeck.core.plugins.PluggableProviderService
import com.dtolabs.rundeck.core.plugins.configuration.Describable
import com.dtolabs.rundeck.core.plugins.configuration.PropertyScope
import com.dtolabs.rundeck.plugins.descriptions.PluginDescription
import com.dtolabs.rundeck.plugins.tours.TourLoaderPlugin

class TourLoaderService {

    def rundeckPluginRegistry
    def pluginService
    def frameworkService

    def listAllTourManifests(String project = null) {
        def tourManifest = []
        PluggableProviderService tourLoaderProviderService = rundeckPluginRegistry.createPluggableService(TourLoaderPlugin.class)

        def loadTours={ def manifest, String title, def prov ->
            def tours = manifest.tours
            def groupedTours = tours.findAll { it.group }
            def ungroupedTours = tours.findAll { !it.group }
            groupedTours.groupBy{ it.group }.each { group, gtours  ->
                tourManifest.add([provider:prov.key,loader:group,tours:gtours])
            }
            if(!ungroupedTours.isEmpty()) {
                tourManifest.add([provider:prov.key,loader:manifest.name ?: title ?: prov.key,tours:ungroupedTours])
            }
        }

        pluginService.listPlugins(TourLoaderPlugin).each { prov ->
            TourLoaderPlugin tourLoader = pluginService.configurePlugin(prov.key, tourLoaderProviderService, frameworkService.getFrameworkPropertyResolver(project), PropertyScope.Instance).instance
            def title = getPluginTitle(tourLoader)
            def manifest = tourLoader.tourManifest
            if(manifest){
                loadTours(manifest, title, prov)
            }

            if(project){
                manifest = tourLoader.getTourManifest(project)
                if(manifest){
                    loadTours(manifest, title, prov)
                }
            }
        }
        return tourManifest
    }

    String getPluginTitle(final TourLoaderPlugin tourLoaderPlugin) {
        if(tourLoaderPlugin instanceof Describable) return tourLoaderPlugin.description?.title
        if(tourLoaderPlugin.class.isAnnotationPresent(PluginDescription)) {
            PluginDescription desc = (PluginDescription)tourLoaderPlugin.class.getAnnotation(PluginDescription)
            return desc.title()
        }
        return null
    }

    Map listTours(String loaderName, String project = null) {
        PluggableProviderService tourLoaderProviderService = rundeckPluginRegistry.createPluggableService(TourLoaderPlugin.class)
        TourLoaderPlugin tourLoader = pluginService.configurePlugin(loaderName, tourLoaderProviderService, frameworkService.getFrameworkPropertyResolver(project), PropertyScope.Instance).instance

        if(project){
            return tourLoader.getTourManifest(project)
        }
        tourLoader.tourManifest
    }

    Map getTour(String loaderName, String tourKey, String project = null) {
        PluggableProviderService tourLoaderProviderService = rundeckPluginRegistry.createPluggableService(TourLoaderPlugin.class)
        TourLoaderPlugin tourLoader = pluginService.configurePlugin(loaderName, tourLoaderProviderService, frameworkService.getFrameworkPropertyResolver(project), PropertyScope.Instance).instance

        def tour = tourLoader.getTour(tourKey)
        if(tour){
            return tour
        }

        if(project){
            return tourLoader.getTour(tourKey,project)
        }

        return null

    }
}
