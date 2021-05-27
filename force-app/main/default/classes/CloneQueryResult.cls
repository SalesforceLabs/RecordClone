public class CloneQueryResult {
    public CloneQueryResult(sObject parent, Map<String, List<sObject>> childrens) {
        this.parent = parent;
        this.childrens = childrens;
    }

    public sObject parent;
    public Map<String, List<sObject>> childrens;
}
