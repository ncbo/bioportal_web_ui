import { application } from '../controllers/application'

import Tabs_container_component_controller
  from '../../components/tabs_container_component/tabs_container_component_controller'

import alert_component_controller from '../../components/display/alert_component/alert_component_controller'


application.register('tabs-container', Tabs_container_component_controller)
application.register('alert-component', alert_component_controller)

