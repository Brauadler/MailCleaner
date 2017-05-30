<?
/**
 * @license http://www.mailcleaner.net/open/licence_en.html Mailcleaner Public License
 * @package mailcleaner
 * @author Olivier Diserens
 * @copyright 2006, Olivier Diserens
 */
 
 
/**
 * This class takes care of storing settings of a simple server
 * @package mailcleaner
 */
 class SimpleServerSettings extends ConnectorSettings {
    
   /**
    * template tag
    * @var string
    */
   protected $template_tag_ = 'SIMPLEAUTH';
   
    /**
   * Specialized settings array with default values
   * @var array
   */
   protected $spec_settings_ = array(
                              'usessl' => false
                             );
   /**
    * fields type
    * @var array
    */
   protected $spec_settings_type_ = array(
                               'usessl' => array('checkbox', '1')
                               );
    
 }
?>
